module WebSocket
  class Protocol

    class Hybi < Protocol
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

      FRAGMENTED_OPCODES = OPCODES.values_at(:continuation, :text, :binary)
      OPENING_OPCODES = OPCODES.values_at(:text, :binary)

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

      ERROR_CODES = ERRORS.values

      def initialize(socket, options = {})
        super
        reset

        @reader    = StreamReader.new
        @stage     = 0
        @masking   = options[:masking]
        @protocols = options[:protocols]
        @protocols = @protocols.strip.split(/\s*,\s*/) if String === @protocols

        @require_masking = options[:require_masking]
        @ping_callbacks  = {}
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
                emit_frame
                @stage = 0
              end
          end
        end
      end

      def frame(data, type = nil, code = nil)
        return queue([data, type, code]) if @ready_state == 0
        return false unless @ready_state == 1

        data = data.to_s unless Array === data
        data = Protocol.encode(data) if String === data

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

        @socket.write(Protocol.encode(frame))
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

        accept    = Hybi.generate_accept(sec_key)
        protos    = @socket.env['HTTP_SEC_WEBSOCKET_PROTOCOL']
        supported = @protocols
        proto     = nil

        headers = [
          "HTTP/1.1 101 Switching Protocols",
          "Upgrade: websocket",
          "Connection: Upgrade",
          "Sec-WebSocket-Accept: #{accept}"
        ]

        if protos and supported
          protos = protos.split(/\s*,\s*/) if String === protos
          proto = protos.find { |p| supported.include?(p) }
          if proto
            @protocol = proto
            headers << "Sec-WebSocket-Protocol: #{proto}"
          end
        end

        (headers + ['','']).join("\r\n")
      end

      def shutdown(code, reason)
        code   ||= ERRORS[:normal_closure]
        reason ||= ''

        frame(reason, :close, code)
        @ready_state = 3
        emit(:close, CloseEvent.new(code, reason))
      end

      def parse_opcode(data)
        if [RSV1, RSV2, RSV3].any? { |rsv| (data & rsv) == rsv }
          return shutdown(ERRORS[:protocol_error], nil)
        end

        @final   = (data & FIN) == FIN
        @opcode  = (data & OPCODE)
        @mask    = []
        @payload = []

        unless OPCODES.values.include?(@opcode)
          return shutdown(ERRORS[:protocol_error], nil)
        end

        unless FRAGMENTED_OPCODES.include?(@opcode) or @final
          return shutdown(ERRORS[:protocol_error], nil)
        end

        if @mode and OPENING_OPCODES.include?(@opcode)
          return shutdown(ERRORS[:protocol_error], nil)
        end

        @stage = 1
      end

      def parse_length(data)
        @masked = (data & MASK) == MASK
        return shutdown(ERRORS[:unacceptable], nil) if @require_masking and not @masked

        @length = (data & LENGTH)

        if @length <= 125
          @stage = @masked ? 3 : 4
        else
          @length_size = (@length == 126) ? 2 : 8
          @stage       = 2
        end
      end

      def parse_extended_length(buffer)
        @length = integer(buffer)
        @stage  = @masked ? 3 : 4
      end

      def emit_frame
        payload = @masked ? Mask.mask(@payload, @mask) : @payload

        case @opcode
          when OPCODES[:continuation] then
            return shutdown(ERRORS[:protocol_error], nil) unless @mode
            @buffer.concat(payload)
            if @final
              message = @buffer
              message = Protocol.encode(message, true) if @mode == :text
              reset
              if message
                emit(:message, MessageEvent.new(message))
              else
                shutdown(ERRORS[:encoding_error], nil)
              end
            end

          when OPCODES[:text] then
            if @final
              message = Protocol.encode(payload, true)
              if message
                emit(:message, MessageEvent.new(message))
              else
                shutdown(ERRORS[:encoding_error], nil)
              end
            else
              @mode = :text
              @buffer.concat(payload)
            end

          when OPCODES[:binary] then
            if @final
              emit(:message, MessageEvent.new(payload))
            else
              @mode = :binary
              @buffer.concat(payload)
            end

          when OPCODES[:close] then
            code = (payload.size >= 2) ? 256 * payload[0] + payload[1] : nil

            unless (payload.size == 0) or
                   (code && code >= 3000 && code < 5000) or
                   ERROR_CODES.include?(code)
              code = ERRORS[:protocol_error]
            end

            if payload.size > 125 or not Protocol.valid_utf8?(payload[2..-1] || [])
              code = ERRORS[:protocol_error]
            end

            reason = (payload.size > 2) ? Protocol.encode(payload[2..-1], true) : ''
            shutdown(code, reason)

          when OPCODES[:ping] then
            return shutdown(ERRORS[:protocol_error], nil) if payload.size > 125
            frame(payload, :pong)

          when OPCODES[:pong] then
            message = Protocol.encode(payload, true)
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

