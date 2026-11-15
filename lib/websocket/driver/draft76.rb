module WebSocket
  class Driver

    class Draft76 < Draft75
      BODY_SIZE = 8

      def initialize(socket, options = {})
        super
        input  = (@socket.env['rack.input'] || StringIO.new('')).read
        input  = input.dup if input.frozen?
        @stage = -1
        @body  = input.force_encoding(Encoding::BINARY)

        @headers.clear
        @headers['Upgrade'] = 'WebSocket'
        @headers['Connection'] = 'Upgrade'
        @headers['Sec-WebSocket-Origin'] = @socket.env['HTTP_ORIGIN']
        @headers['Sec-WebSocket-Location'] = @socket.url
      end

      def version
        'hixie-76'
      end

      def start
        return false unless super
        send_handshake_body
        true
      end

      def close(reason = nil, code = nil)
        return false if @ready_state == 3
        @socket.write([0xFF, 0x00].pack('C*')) if @ready_state == 1
        @ready_state = 3
        emit(:close, CloseEvent.new(nil, nil))
        true
      end

    private

      def handshake_response
        env  = @socket.env
        key1 = env['HTTP_SEC_WEBSOCKET_KEY1']
        key2 = env['HTTP_SEC_WEBSOCKET_KEY2']

        raise ProtocolError.new('Missing required header: Sec-WebSocket-Key1') unless key1
        raise ProtocolError.new('Missing required header: Sec-WebSocket-Key2') unless key2

        @key_values = [get_key_value(key1), get_key_value(key2)]

        start   = 'HTTP/1.1 101 WebSocket Protocol Handshake'
        headers = [start, @headers.to_s, '']
        headers.join("\r\n")
      end

      def handshake_signature
        return nil unless @body.bytesize >= BODY_SIZE

        head = @body[0...BODY_SIZE]
        Digest::MD5.digest((@key_values + [head]).pack('N2A*'))
      end

      def send_handshake_body
        return unless signature = handshake_signature
        @socket.write(signature)
        @stage = 0
        open
        parse(@body[BODY_SIZE..-1]) if @body.bytesize > BODY_SIZE
      end

      def parse_leading_byte(octet)
        return super unless octet == 0xFF
        @closing = true
        @length  = 0
        @stage   = 1
      end

      def get_key_value(key)
        digits = key.scan(/[0-9]/).join('')
        number = (digits == '') ? 0 : digits.to_i(10)
        spaces = key.scan(/ /).size

        if number == 0 or spaces == 0 or number % spaces != 0
          raise ProtocolError.new('Client sent invalid Sec-WebSocket-Key headers')
        end

        div = number / spaces

        if div <= 0xffffffff
          div
        else
          raise ProtocolError.new('Client sent invalid Sec-WebSocket-Key headers')
        end
      end
    end

  end
end
