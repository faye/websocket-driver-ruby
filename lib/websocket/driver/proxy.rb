module WebSocket
  class Driver

    class Proxy
      include EventEmitter

      PORTS = {'ws' => 80, 'wss' => 443}

      attr_reader :status, :headers

      def initialize(client, origin, options)
        super()

        @client = client
        @headers = Headers.new
        @http    = HTTP::Response.new
        @socket  = client.instance_variable_get(:@socket)
        @origin  = URI.parse(@socket.url)
        @url     = URI.parse(origin)
        @options = options
        @state   = 0
      end

      def set_header(name, value)
        return false unless @state == 0
        @headers[name] = value
        true
      end

      def start
        return false unless @state == 0
        @state = 1

        host = @origin.host + (@origin.port ? ":#{@origin.port}" : '')
        port = @origin.port || PORTS[@origin.scheme]

        headers = [ "CONNECT #{@origin.host}:#{port} HTTP/1.1",
                    "Host: #{host}",
                    "Connection: keep-alive",
                    "Proxy-Connection: keep-alive"
                  ]

        if @url.user
          auth = Base64.encode64([@url.user, @url.password] * ':').gsub(/\n/, '')
          headers << "Proxy-Authorization: Basic #{auth}"
        end

        @socket.write((headers + [@headers.to_s, '']).join("\r\n"))
        true
      end

      def parse(buffer)
        return @delegate.parse(buffer) if @delegate

        @http.parse(buffer)
        return unless @http.complete?

        @status = @http.code
        @headers = Headers.new(@http.headers)

        if @status != 200
          message = "Can't establish a connection to the server at #{@socket.url}"
          emit(:error, ProtocolError.new(message))
          @ready_state = 3
          return emit(:close, CloseEvent.new(1006, ''))
        end

        @socket.start_tls if @origin.scheme == 'wss'
        configure_delegate(@client)
        @client.start
      end

    private

      def configure_delegate(delegate)
        @delegate = delegate
      end
    end

  end
end
