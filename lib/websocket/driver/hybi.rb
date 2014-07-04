module WebSocket
  class Driver

    class Hybi < Driver
      root = File.expand_path('../hybi', __FILE__)
      autoload :StreamReader, root + '/stream_reader'

      def self.generate_accept(key)
        Base64.encode64(Digest::SHA1.digest(key + GUID)).strip
      end

      GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11'

      BYTE       = 0b11111111
      FIN = MASK = 0b10000000
      RSV1       = 0b01000000
      RSV2       = 0b00100000
      RSV3       = 0b00010000
      OPCODE     = 0b00001111
      LENGTH     = 0b01111111

      OPCODES = {
        :continuation => 0,
        :text         => 1,
        :binary       => 2,
        :close        => 8,
        :ping         => 9,
        :pong         => 10
      }

      OPCODE_CODES       = OPCODES.values
      FRAGMENTED_OPCODES = OPCODES.values_at(:continuation, :text, :binary)
      OPENING_OPCODES    = OPCODES.values_at(:text, :binary)

      ERRORS = {
        :normal_closure       => 1000,
        :going_away           => 1001,
        :protocol_error       => 1002,
        :unacceptable         => 1003,
        :encoding_error       => 1007,
        :policy_violation     => 1008,
        :too_large            => 1009,
        :extension_error      => 1010,
        :unexpected_condition => 1011
      }

      ERROR_CODES        = ERRORS.values
      MIN_RESERVED_ERROR = 3000
      MAX_RESERVED_ERROR = 4999

      def initialize(socket, options = {})
        super
        reset

        @reader          = StreamReader.new
        @stage           = 0
        @masking         = options[:masking]
        @protocols       = options[:protocols] || []
        @protocols       = @protocols.strip.split(/\s*,\s*/) if String === @protocols
        @require_masking = options[:require_masking]
        @ping_callbacks  = {}

        return unless @socket.respond_to?(:env)

        if protos = @socket.env['HTTP_SEC_WEBSOCKET_PROTOCOL']
          protos = protos.split(/\s*,\s*/) if String === protos
          @protocol = protos.find { |p| @protocols.include?(p) }
        end
      end

      def version
        "hybi-#{@socket.env['HTTP_SEC_WEBSOCKET_VERSION']}"
      end

      def parse(data)
        data = data.bytes.to_a if data.respond_to?(:bytes)
        @reader.put(data)
        buffer = true
        while buffer
          case @stage
            when 0 then
              buffer = @reader.read(1)
              parse_opcode(buffer[0]) if buffer

            when 1 then
              buffer = @reader.read(1)
              parse_length(buffer[0]) if buffer

            when 2 then
              buffer = @reader.read(@length_size)
              parse_extended_length(buffer) if buffer

            when 3 then
              buffer = @reader.read(4)
              if buffer
                @mask  = buffer
                @stage = 4
              end

            when 4 then
              buffer = @reader.read(@length)
              if buffer
                @payload = buffer
                emit_frame(buffer)
                @stage = 0
              end

            else
              buffer = nil
          end
        end
      end

      def frame(data, type = nil, code = nil)
        return queue([data, type, code]) if @ready_state <= 0
        return false unless @ready_state == 1

        data = data.to_s unless Array === data
        data = Driver.encode(data, :utf8) if String === data

        is_text = (String === data)
        opcode  = OPCODES[type || (is_text ? :text : :binary)]
        buffer  = data.respond_to?(:bytes) ? data.bytes.to_a : data
        insert  = code ? 2 : 0
        length  = buffer.size + insert
        header  = (length <= 125) ? 2 : (length <= 65535 ? 4 : 10)
        offset  = header + (@masking ? 4 : 0)
        masked  = @masking ? MASK : 0
        frame   = Array.new(offset)

        frame[0] = FIN | opcode

        if length <= 125
          frame[1] = masked | length
        elsif length <= 65535
          frame[1] = masked | 126
          frame[2] = (length >> 8) & BYTE
          frame[3] = length & BYTE
        else
          frame[1] = masked | 127
          frame[2] = (length >> 56) & BYTE
          frame[3] = (length >> 48) & BYTE
          frame[4] = (length >> 40) & BYTE
          frame[5] = (length >> 32) & BYTE
          frame[6] = (length >> 24) & BYTE
          frame[7] = (length >> 16) & BYTE
          frame[8] = (length >> 8)  & BYTE
          frame[9] = length & BYTE
        end

        if code
          buffer = [(code >> 8) & BYTE, code & BYTE] + buffer
        end

        if @masking
          mask = [rand(256), rand(256), rand(256), rand(256)]
          frame[header...offset] = mask
          buffer = Mask.mask(buffer, mask)
        end

        frame.concat(buffer)

        @socket.write(Driver.encode(frame, :binary))
        true
      end

      def text(message)
        frame(message, :text)
      end

      def binary(message)
        frame(message, :binary)
      end

      def ping(message = '', &callback)
        @ping_callbacks[message] = callback if callback
        frame(message, :ping)
      end

      def close(reason = nil, code = nil)
        reason ||= ''
        code   ||= ERRORS[:normal_closure]

        case @ready_state
          when 0 then
            @ready_state = 3
            emit(:close, CloseEvent.new(code, reason))
            true
          when 1 then
            frame(reason, :close, code)
            @ready_state = 2
            true
          else
            false
        end
      end

    private

      def handshake_response
        sec_key = @socket.env['HTTP_SEC_WEBSOCKET_KEY']
        return '' unless String === sec_key

        headers = [
          "HTTP/1.1 101 Switching Protocols",
          "Upgrade: websocket",
          "Connection: Upgrade",
          "Sec-WebSocket-Accept: #{Hybi.generate_accept(sec_key)}"
        ]

        if @protocol
          headers << "Sec-WebSocket-Protocol: #{@protocol}"
        end

        (headers + [@headers.to_s, '']).join("\r\n")
      end

      def shutdown(code, reason)
        frame(reason, :close, code)
        @ready_state = 3
        @stage = 5
        emit(:close, CloseEvent.new(code, reason))
      end

      def fail(type, message)
        emit(:error, ProtocolError.new(message))
        shutdown(ERRORS[type], message)
      end

      def parse_opcode(data)
        rsvs = [RSV1, RSV2, RSV3].map { |rsv| (data & rsv) == rsv }

        if rsvs.any?
          return fail(:protocol_error,
              "One or more reserved bits are on: reserved1 = #{rsvs[0] ? 1 : 0}" +
              ", reserved2 = #{rsvs[1] ? 1 : 0 }" +
              ", reserved3 = #{rsvs[2] ? 1 : 0 }")
        end

        @final   = (data & FIN) == FIN
        @opcode  = (data & OPCODE)

        unless OPCODES.values.include?(@opcode)
          return fail(:protocol_error, "Unrecognized frame opcode: #{@opcode}")
        end

        unless FRAGMENTED_OPCODES.include?(@opcode) or @final
          return fail(:protocol_error, "Received fragmented control frame: opcode = #{@opcode}")
        end

        if @mode and OPENING_OPCODES.include?(@opcode)
          return fail(:protocol_error, 'Received new data frame but previous continuous frame is unfinished')
        end

        @stage = 1
      end

      def parse_length(data)
        @masked = (data & MASK) == MASK
        if @require_masking and not @masked
          return fail(:unacceptable, 'Received unmasked frame but masking is required')
        end

        @length = (data & LENGTH)

        if @length >= 0 and @length <= 125
          return unless check_frame_length
          @stage = @masked ? 3 : 4
        else
          @length_size = (@length == 126) ? 2 : 8
          @stage       = 2
        end
      end

      def parse_extended_length(buffer)
        @length = integer(buffer)

        unless FRAGMENTED_OPCODES.include?(@opcode) or @length <= 125
          return fail(:protocol_error, "Received control frame having too long payload: #{@length}")
        end

        return unless check_frame_length

        @stage  = @masked ? 3 : 4
      end

      def check_frame_length
        if @buffer.size + @length > @max_length
          fail(:too_large, 'WebSocket frame length too large')
          false
        else
          true
        end
      end

      def emit_frame(buffer)
        payload  = Mask.mask(buffer, @mask)
        is_final = @final
        opcode   = @opcode

        @final = @opcode = @length = @length_size = @masked = @mask = nil

        case opcode
          when OPCODES[:continuation] then
            return fail(:protocol_error, 'Received unexpected continuation frame') unless @mode
            @buffer.concat(payload)
            if is_final
              message = @buffer
              message = Driver.encode(message, :utf8) if @mode == :text
              reset
              if message
                emit(:message, MessageEvent.new(message))
              else
                fail(:encoding_error, 'Could not decode a text frame as UTF-8')
              end
            end

          when OPCODES[:text] then
            if is_final
              message = Driver.encode(payload, :utf8)
              if message
                emit(:message, MessageEvent.new(message))
              else
                fail(:encoding_error, 'Could not decode a text frame as UTF-8')
              end
            else
              @mode = :text
              @buffer.concat(payload)
            end

          when OPCODES[:binary] then
            if is_final
              emit(:message, MessageEvent.new(payload))
            else
              @mode = :binary
              @buffer.concat(payload)
            end

          when OPCODES[:close] then
            code = (payload.size >= 2) ? 256 * payload[0] + payload[1] : nil

            unless (payload.size == 0) or
                   (code && code >= MIN_RESERVED_ERROR && code <= MAX_RESERVED_ERROR) or
                   ERROR_CODES.include?(code)
              code = ERRORS[:protocol_error]
            end

            message = Driver.encode(payload[2..-1] || [], :utf8)

            if payload.size > 125 or message.nil?
              code = ERRORS[:protocol_error]
            end

            reason = (payload.size > 2) ? message : ''
            shutdown(code, reason || '')

          when OPCODES[:ping] then
            frame(payload, :pong)

          when OPCODES[:pong] then
            message = Driver.encode(payload, :utf8)
            callback = @ping_callbacks[message]
            @ping_callbacks.delete(message)
            callback.call if callback
        end
      end

      def reset
        @buffer = []
        @mode   = nil
      end

      def integer(bytes)
        number = 0
        bytes.each_with_index do |data, i|
          number += data << (8 * (bytes.size - 1 - i))
        end
        number
      end
    end

  end
end
