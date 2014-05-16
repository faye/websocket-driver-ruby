module WebSocket
  class Driver

    class Draft76 < Draft75
      BODY_SIZE = 8

      def initialize(socket, options = {})
        super
        input  = @socket.env['rack.input']
        @stage = -1
        @body  = input ? input.read.bytes.to_a : []
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
        @socket.write(Driver.encode("\xFF\x00", :binary))
        @ready_state = 3
        emit(:close, CloseEvent.new(nil, nil))
        true
      end

    private

      def handshake_response
        upgrade =  "HTTP/1.1 101 WebSocket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "Sec-WebSocket-Origin: #{@socket.env['HTTP_ORIGIN']}\r\n"
        upgrade << "Sec-WebSocket-Location: #{@socket.url}\r\n"
        upgrade << @headers.to_s
        upgrade << "\r\n"
        upgrade
      end

      def handshake_signature
        return nil unless @body.size >= BODY_SIZE

        head = @body[0...BODY_SIZE].pack('C*')
        head.force_encoding('ASCII-8BIT') if head.respond_to?(:force_encoding)

        env = @socket.env

        key1   = env['HTTP_SEC_WEBSOCKET_KEY1']
        value1 = number_from_key(key1) / spaces_in_key(key1)

        key2   = env['HTTP_SEC_WEBSOCKET_KEY2']
        value2 = number_from_key(key2) / spaces_in_key(key2)

        Digest::MD5.digest(big_endian(value1) +
                           big_endian(value2) +
                           head)
      end

      def send_handshake_body
        return unless signature = handshake_signature
        @socket.write(Driver.encode(signature, :binary))
        @stage = 0
        open
        parse(@body[BODY_SIZE..-1]) if @body.size > BODY_SIZE
      end

      def parse_leading_byte(data)
        return super unless data == 0xFF
        @closing = true
        @length = 0
        @stage = 1
      end

      def number_from_key(key)
        key.scan(/[0-9]/).join('').to_i(10)
      end

      def spaces_in_key(key)
        key.scan(/ /).size
      end

      def big_endian(number)
        string = ''
        [24, 16, 8, 0].each do |offset|
          string << (number >> offset & 0xFF).chr
        end
        string
      end
    end

  end
end
