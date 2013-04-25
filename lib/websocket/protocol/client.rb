module WebSocket
  class Protocol

    class Client < Hybi
      def self.generate_key
        Base64.encode64((1..16).map { rand(255).chr } * '').strip
      end

      def initialize(socket, options = {})
        super

        @ready_state = -1
        @key         = Client.generate_key
        @accept      = Base64.encode64(Digest::SHA1.digest(@key + GUID)).strip
        @origin      = options.fetch(:origin) { nil }
      end

      def start
        return false unless @ready_state == -1
        puts handshake_request
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
              if @buffer[-4..-1] == [0x0D, 0x0A, 0x0D, 0x0A]
                if valid?
                  open
                else
                  @ready_state = 3
                  dispatch(:onclose, CloseEvent.new(ERRORS[:protocol_error], ''))
                end
              end
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

        if @origin
          headers << "Origin: #{@origin}"
        end

        if @protocols
          headers << "Sec-WebSocket-Protocol: #{@protocols * ', '}"
        end

        (headers + ['', '']).join("\r\n")
      end

      def valid?
        data = Protocol.encode(@buffer)
        @buffer = []

        response = Net::HTTPResponse.read_new(Net::BufferedIO.new(StringIO.new(data)))
        return false unless response.code.to_i == 101

        connection = response['Connection'] || ''
        upgrade    = response['Upgrade'] || ''
        accept     = response['Sec-WebSocket-Accept']
        protocol   = response['Sec-WebSocket-Protocol']

        @protocol = @protocols && @protocols.include?(protocol) ?
                    protocol :
                    nil

        connection.downcase.split(/\s*,\s*/).include?('upgrade') and
        upgrade.downcase == 'websocket' and
        ((!@protocols and !protocol) or @protocol) and
        accept == @accept
      end
    end

  end
end

