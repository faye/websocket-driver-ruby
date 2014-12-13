module WebSocket
  class Driver

    class Draft75 < Driver
      def initialize(socket, options = {})
        super
        @stage = 0

        @headers['Upgrade'] = 'WebSocket'
        @headers['Connection'] = 'Upgrade'
        @headers['WebSocket-Origin'] = @socket.env['HTTP_ORIGIN']
        @headers['WebSocket-Location'] = @socket.url
      end

      def version
        'hixie-75'
      end

      def close(reason = nil, code = nil)
        return false if @ready_state == 3
        @ready_state = 3
        emit(:close, CloseEvent.new(nil, nil))
        true
      end

      def parse(buffer)
        return if @ready_state > 1

        buffer.each_byte do |data|
          case @stage
            when -1 then
              @body << data
              send_handshake_body

            when 0 then
              parse_leading_byte(data)

            when 1 then
              value = (data & 0x7F)
              @length = value + 128 * @length

              if @closing and @length.zero?
                return close
              elsif (0x80 & data) != 0x80
                if @length.zero?
                  @stage = 0
                else
                  @skipped = 0
                  @stage = 2
                end
              end

            when 2 then
              if data == 0xFF
                emit(:message, MessageEvent.new(Driver.encode(@buffer, :utf8)))
                @stage = 0
              else
                if @length
                  @skipped += 1
                  @stage = 0 if @skipped == @length
                else
                  @buffer << data
                  return close if @buffer.size > @max_length
                end
              end
          end
        end
      end

      def frame(data, type = nil, error_type = nil)
        return queue([data, type, error_type]) if @ready_state == 0
        frame = ["\x00", data, "\xFF"].map { |s| Driver.encode(s, :binary) } * ''
        @socket.write(Driver.encode(frame, :binary))
        true
      end

    private

      def handshake_response
        start   = 'HTTP/1.1 101 Web Socket Protocol Handshake'
        headers = [start, @headers.to_s, '']
        headers.join("\r\n")
      end

      def parse_leading_byte(data)
        if (0x80 & data) == 0x80
          @length = 0
          @stage  = 1
        else
          @length  = nil
          @skipped = nil
          @buffer  = []
          @stage   = 2
        end
      end
    end

  end
end
