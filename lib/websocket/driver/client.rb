module WebSocket
  class Driver

    class Client < Hybi
      def self.generate_key
        Base64.encode64((1..16).map { rand(255).chr } * '').strip
      end

      def initialize(socket, options = {})
        super

        @ready_state = -1
        @key         = Client.generate_key
        @accept      = Hybi.generate_accept(@key)
      end

      def version
        'hybi-13'
      end

      def start
        return false unless @ready_state == -1
        @socket.write(handshake_request)
        @ready_state = 0
        true
      end

      def parse(buffer)
        return super if @ready_state > 0
        message = []
        buffer.each_byte do |data|
          case @ready_state
            when 0 then
              @buffer << data
              validate_handshake if @buffer[-4..-1] == [0x0D, 0x0A, 0x0D, 0x0A]
            when 1 then
              message << data
          end
        end
        parse(message) if @ready_state == 1
      end

    private 

      def handshake_request
        uri   = URI.parse(@socket.url)
        host  = uri.host + (uri.port ? ":#{uri.port}" : '')
        path  = (uri.path == '') ? '/' : uri.path
        query = uri.query ? "?#{uri.query}" : ''

        headers = [ "GET #{path}#{query} HTTP/1.1",
                    "Host: #{host}",
                    "Upgrade: websocket",
                    "Connection: Upgrade",
                    "Sec-WebSocket-Key: #{@key}",
                    "Sec-WebSocket-Version: 13"
                  ]

        if @protocols.size > 0
          headers << "Sec-WebSocket-Protocol: #{@protocols * ', '}"
        end

        (headers + ['', '']).join("\r\n")
      end

      def fail_handshake(message)
        message = "Error during WebSocket handshake: #{message}"
        emit(:error, ProtocolError.new(message))
        @ready_state = 3
        emit(:close, CloseEvent.new(ERRORS[:protocol_error], message))
      end

      def validate_handshake
        data     = Driver.encode(@buffer)
        @buffer  = []
        response = Net::HTTPResponse.read_new(Net::BufferedIO.new(StringIO.new(data)))

        unless response.code.to_i == 101
          return fail_handshake("Unexpected response code: #{response.code}")
        end

        upgrade    = response['Upgrade'] || ''
        connection = response['Connection'] || ''
        accept     = response['Sec-WebSocket-Accept'] || ''
        protocol   = response['Sec-WebSocket-Protocol'] || ''

        if upgrade == ''
          return fail_handshake("'Upgrade' header is missing")
        elsif upgrade.downcase != 'websocket'
          return fail_handshake("'Upgrade' header value is not 'WebSocket'")
        end

        if connection == ''
          return fail_handshake("'Connection' header is missing")
        elsif connection.downcase != 'upgrade'
          return fail_handshake("'Connection' header value is not 'Upgrade'")
        end

        unless accept == @accept
          return fail_handshake('Sec-WebSocket-Accept mismatch')
        end

        unless protocol == ''
          if @protocols.include?(protocol)
            @protocol = protocol
          else
            return fail_handshake('Sec-WebSocket-Protocol mismatch')
          end
        end

        open
      end
    end

  end
end

