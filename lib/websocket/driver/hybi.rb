module WebSocket
  class Driver

    class Hybi < Driver
      root = File.expand_path('../hybi', __FILE__)

      autoload :Frame,    root + '/frame'
      autoload :Message,  root + '/message'
      autoload :Parser,   root + '/parser'
      autoload :Unparser, root + '/unparser'

      def self.generate_accept(key)
        Base64.strict_encode64(Digest::SHA1.digest(key + GUID))
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

      OPCODE_CODES    = OPCODES.values
      MESSAGE_OPCODES = OPCODES.values_at(:continuation, :text, :binary)
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

      ERROR_CODES        = ERRORS.values
      DEFAULT_ERROR_CODE = 1000
      MIN_RESERVED_ERROR = 3000
      MAX_RESERVED_ERROR = 4999

      PACK_FORMATS = {2 => 'n', 8 => 'Q>'}

      def initialize(socket, options = {})
        super

        @parser     = (options[:parser_class] || Hybi::Parser).new(self, options[:require_masking])
        @unparser   = (options[:unparser_class] || Hybi::Unparser).new(self, options[:masking])
        @extensions = ::WebSocket::Extensions.new

        @protocols      = options[:protocols] || []
        @protocols      = @protocols.strip.split(/ *, */) if String === @protocols
        @ping_callbacks = {}

        return unless @socket.respond_to?(:env)

        sec_key = @socket.env['HTTP_SEC_WEBSOCKET_KEY']
        protos  = @socket.env['HTTP_SEC_WEBSOCKET_PROTOCOL']

        @headers['Upgrade']              = 'websocket'
        @headers['Connection']           = 'Upgrade'
        @headers['Sec-WebSocket-Accept'] = Hybi.generate_accept(sec_key)

        if protos = @socket.env['HTTP_SEC_WEBSOCKET_PROTOCOL']
          protos = protos.split(/ *, */) if String === protos
          @protocol = protos.find { |p| @protocols.include?(p) }
          @headers['Sec-WebSocket-Protocol'] = @protocol if @protocol
        end
      end

      def version
        "hybi-#{@socket.env['HTTP_SEC_WEBSOCKET_VERSION']}"
      end

      def add_extension(extension)
        @extensions.add(extension)
        true
      end

      def parse(chunk)
        @parser.parse(chunk) if @parser
        reraise_emit_exception
      end

      def binary(message)
        frame(message, :binary)
      end

      def ping(message = '', &callback)
        @ping_callbacks[message] = callback if callback
        frame(message, :ping)
      end

      def pong(message = '')
        frame(message, :pong)
      end

      def close(reason = nil, code = nil)
        reason ||= ''
        code   ||= ERRORS[:normal_closure]

        if @ready_state <= 0
          @ready_state = 3
          emit(:close, CloseEvent.new(code, reason))
          true
        elsif @ready_state == 1
          frame(reason, :close, code)
          @ready_state = 2
          true
        else
          false
        end
      end

      def frame(buffer, type = nil, code = nil)
        return queue([buffer, type, code]) if @ready_state <= 0
        return false unless @ready_state == 1

        message = Message.new
        is_text = String === buffer

        message.rsv1   = message.rsv2 = message.rsv3 = false
        message.opcode = OPCODES[type || (is_text ? :text : :binary)]

        payload = is_text ? buffer.bytes.to_a : buffer
        payload = [code].pack(PACK_FORMATS[2]).bytes.to_a + payload if code
        message.data = payload.pack('C*')

        if MESSAGE_OPCODES.include?(message.opcode)
          message = @extensions.process_outgoing_message(message)
        end

        string = @unparser.frame([true, message.rsv1, message.rsv2, message.rsv3, message.opcode],
                                 SecureRandom.random_bytes(4), message.data)

        @socket.write(string)

        true

      rescue ::WebSocket::Extensions::ExtensionError => error
        fail(:extension_error, error.message)
      end

    private

      def handshake_response
        begin
          extensions = @extensions.generate_response(@socket.env['HTTP_SEC_WEBSOCKET_EXTENSIONS'])
        rescue => error
          fail(:protocol_error, error.message)
          return nil
        end

        @headers['Sec-WebSocket-Extensions'] = extensions if extensions

        start   = 'HTTP/1.1 101 Switching Protocols'
        headers = [start, @headers.to_s, '']
        headers.join("\r\n")
      end

      def valid_frame_rsv?(rsv1, rsv2, rsv3, opcode)
        frame = Frame.new

        frame.rsv1   = rsv1
        frame.rsv2   = rsv2
        frame.rsv3   = rsv3
        frame.opcode = opcode

        @extensions.valid_frame_rsv?(frame)
      end

      def handle_error(code, reason)
        fail(code, reason)
      end

      def handle_message(opcode, rsv1, rsv2, rsv3, data)
        message = Message.new

        message.opcode = opcode
        message.rsv1   = rsv1
        message.rsv2   = rsv2
        message.rsv3   = rsv3
        message.data   = data

        message = @extensions.process_incoming_message(message)

        payload = case opcode
          when OPCODES[:text]   then Driver.encode(message.data, UNICODE)
          when OPCODES[:binary] then message.data.bytes.to_a
        end

        if payload.nil?
          fail(:encoding_error, 'Could not decode a text frame as UTF-8')
        end

        emit(:message, MessageEvent.new(payload))

      rescue ::WebSocket::Extensions::ExtensionError => error
        fail(:extension_error, error.message)
      end

      def handle_close(code, reason)
        reason = Driver.encode(reason, UNICODE)
        code = ERRORS[:protocol_error] if reason.nil? # TODO emit error
        shutdown(code, reason || '')
      end

      def handle_ping(payload)
        frame(payload, :pong)
      end

      def handle_pong(payload)
        message = Driver.encode(payload, UNICODE)
        callback = @ping_callbacks[message]
        @ping_callbacks.delete(message)
        callback.call if callback
      end

      def shutdown(code, reason, error = false)
        @extensions.close

        frame(reason, :close, code) if @ready_state < 2
        @ready_state = 3

        @parser = @unparser = nil

        emit(:error, ProtocolError.new(reason)) if error
        emit(:close, CloseEvent.new(code, reason))
      end

      def fail(type, message)
        return if @ready_state > 1
        shutdown(ERRORS[type] || type, message, true)
      end
    end

  end
end
