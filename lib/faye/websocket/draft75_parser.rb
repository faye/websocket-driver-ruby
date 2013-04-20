module Faye
  class WebSocket

    class Draft75Parser < Parser
      attr_reader :protocol

      def initialize(web_socket, options = {})
        super
        @stage = 0
      end

      def version
        'hixie-75'
      end

      def parse(buffer)
        buffer = buffer.bytes if buffer.respond_to?(:bytes)

        buffer.each do |data|
          case @stage
            when -1 then
              @head << data
              send_handshake_body

            when 0 then
              parse_leading_byte(data)

            when 1 then
              value = (data & 0x7F)
              @length = value + 128 * @length

              if @closing and @length.zero?
                @ready_state = 3
                dispatch(:onclose, nil, nil)
              elsif (0x80 & data) != 0x80
                if @length.zero?
                  dispatch(:onmessage, '')
                  @stage = 0
                else
                  @buffer = []
                  @stage = 2
                end
              end

            when 2 then
              if data == 0xFF
                dispatch(:onmessage, WebSocket.encode(@buffer))
                @stage = 0
              else
                @buffer << data
                if @length and @buffer.size == @length
                  @stage = 0
                end
              end
          end
        end
      end

      def frame(data, type = nil, error_type = nil)
        return queue([data, type, error_type]) if @ready_state == 0
        data = WebSocket.encode(data)
        frame = ["\x00", data, "\xFF"].map(&WebSocket.method(:encode)) * ''
        @socket.write(frame)
        true
      end

    private

      def handshake_response
        upgrade =  "HTTP/1.1 101 Web Socket Protocol Handshake\r\n"
        upgrade << "Upgrade: WebSocket\r\n"
        upgrade << "Connection: Upgrade\r\n"
        upgrade << "WebSocket-Origin: #{@socket.env['HTTP_ORIGIN']}\r\n"
        upgrade << "WebSocket-Location: #{@socket.url}\r\n"
        upgrade << "\r\n"
        upgrade
      end

      def parse_leading_byte(data)
        if (0x80 & data) == 0x80
          @length = 0
          @stage = 1
        else
          @length = nil
          @buffer = []
          @stage = 2
        end
      end
    end

  end
end

