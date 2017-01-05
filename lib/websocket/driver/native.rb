module WebSocket
  class Driver

    class Native < Driver
      def initialize(socket, options = {})
        super

        @parser     = ::WebSocketNative::Parser.new(self, options.fetch(:require_masking, false))
        @unparser   = ::WebSocketNative::Unparser.new(self, options.fetch(:masking, false))
        @extensions = ::WebSocket::Extensions.new

        @protocols = options[:protocols] || []
        @protocols = @protocols.strip.split(/ *, */) if String === @protocols

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
        @parser.parse(chunk)
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
        code   ||= Hybi::ERRORS[:normal_closure]

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

        message = Hybi::Message.new
        frame   = Hybi::Frame.new
        is_text = String === buffer

        message.rsv1   = message.rsv2 = message.rsv3 = false
        message.opcode = Hybi::OPCODES[type || (is_text ? :text : :binary)]

        payload = is_text ? buffer.bytes.to_a : buffer
        payload = [code].pack(Hybi::PACK_FORMATS[2]).bytes.to_a + payload if code
        message.data = payload.pack('C*')

        if Hybi::MESSAGE_OPCODES.include?(message.opcode)
          message = @extensions.process_outgoing_message(message)
        end

        frame.final       = true
        frame.rsv1        = message.rsv1
        frame.rsv2        = message.rsv2
        frame.rsv3        = message.rsv3
        frame.opcode      = message.opcode
        frame.masking_key = SecureRandom.random_bytes(4)
        frame.length      = message.data.bytesize
        frame.payload     = message.data

        string = @unparser.frame(frame.final, frame.rsv1, frame.rsv2, frame.rsv3,
                                 frame.opcode, frame.masking_key, frame.payload)

        @socket.write(string)

        true

      rescue ::WebSocket::Extensions::ExtensionError => error
        fail(:extension_error, error.message)
      end

    private

      def handle_error(code, reason)
        fail(code, reason)
      end

      def handle_message(opcode, rsv1, rsv2, rsv3, data)
        message = Hybi::Message.new

        message.opcode = opcode
        message.rsv1   = rsv1
        message.rsv2   = rsv2
        message.rsv3   = rsv3
        message.data   = data

        message = @extensions.process_incoming_message(message)

        payload = case opcode
          when Hybi::OPCODES[:text]   then Driver.encode(message.data, UNICODE)
          when Hybi::OPCODES[:binary] then message.data.bytes.to_a
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
        code = Hybi::ERRORS[:protocol_error] if reason.nil? # TODO emit error
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

      def shutdown(code, reason, error = false)
        @frame = @message = nil
        @stage = 5
        @extensions.close

        frame(reason, :close, code) if @ready_state < 2
        @ready_state = 3

        emit(:error, ProtocolError.new(reason)) if error
        emit(:close, CloseEvent.new(code, reason))
      end

      def fail(type, message)
        return if @ready_state > 1
        shutdown(Hybi::ERRORS.fetch(type, type), message, true)
      end
    end

  end
end
