module WebSocket
  class Driver

    class Client < Hybi
      def self.generate_key
        Base64.encode64((1..16).map { rand(255).chr } * '').strip
      end

      attr_reader :status, :headers

      def initialize(socket, options = {})
        super

        @ready_state = -1
        @key         = Client.generate_key
        @accept      = Hybi.generate_accept(@key)
        @http        = HTTP::Response.new
      end

      def version
        'hybi-13'
      end

      def start
        return false unless @ready_state == -1
        @socket.write(Driver.encode(handshake_request, :binary))
        @ready_state = 0
        true
      end

      def parse(buffer)
        return super if @ready_state > 0
        @http.parse(buffer)
        return fail_handshake('Invalid HTTP response') if @http.error?
        validate_handshake if @http.complete?
        parse(@http.body) if @ready_state == 1
      end

    private 

      def handshake_request
        uri   = URI.parse(@socket.url)
        host  = uri.host + (uri.port ? ":#{uri.port}" : '')
        path  = (uri.path == '') ? '/' : uri.path
        query = uri.query ? "?#{uri.query}" : ''
        scheme = uri.scheme === "wss" ? "https" : "http"

        headers = [ "GET #{path}#{query} HTTP/1.1",
                    "Host: #{host}",
                    "Upgrade: websocket",
                    "Connection: Upgrade",
                    "Sec-WebSocket-Key: #{@key}",
                    "Sec-WebSocket-Version: 13",
                    "Origin: #{scheme}://#{host}"
                  ]

        if @protocols.size > 0
          headers << "Sec-WebSocket-Protocol: #{@protocols * ', '}"
        end

        if uri.user
          auth = Base64.encode64([uri.user, uri.password] * ':').gsub(/\n/, '')
          headers << "Authorization: Basic #{auth}"
        end

        (headers + [@headers.to_s, '']).join("\r\n")
      end

      def fail_handshake(message)
        message = "Error during WebSocket handshake: #{message}"
        emit(:error, ProtocolError.new(message))
        @ready_state = 3
        emit(:close, CloseEvent.new(ERRORS[:protocol_error], message))
      end

      def validate_handshake
        @status  = @http.code
        @headers = Headers.new(@http.headers)

        unless @http.code == 101
          return fail_handshake("Unexpected response code: #{@http.code}")
        end

        upgrade    = @http['Upgrade'] || ''
        connection = @http['Connection'] || ''
        accept     = @http['Sec-WebSocket-Accept'] || ''
        protocol   = @http['Sec-WebSocket-Protocol'] || ''

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

