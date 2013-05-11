module WebSocket
  module HTTP

    module Headers
      MAX_LINE_LENGTH = 4096
      CR = 0x0D
      LF = 0x0A

      HEADER_LINE = /^([!#\$%&'\*\+\-\.\^_`\|~0-9a-z]+):\s*((?:\t|[\x20-\x7e])*?)\s*$/i

      def initialize
        @buffer  = []
        @headers = {}
        @stage   = 0
      end

      def error?
        @stage == -1
      end

      def complete?
        @stage == 2
      end

      def [](name)
        @headers[normalize_header(name)]
      end

      def body
        @buffer.pack('C*')
      end

      def parse(data)
        data.each_byte do |byte|
          if byte == LF
            @buffer.pop if @buffer.last == CR
            if @buffer.empty?
              @stage = 2 if @stage == 1
            else
              on_line(@buffer.pack('C*'))
            end
            @buffer = []
          else
            @buffer << byte if @stage >= 0
            error if @stage < 2 and @buffer.size > MAX_LINE_LENGTH
          end
        end
      end

    private

      def error
        @stage = -1
      end

      def on_line(line)
        return error unless parsed = line.scan(HEADER_LINE).first
        @headers[normalize_header(parsed[0])] = parsed[1].strip
      end

      def normalize_header(name)
        name.downcase.gsub(/^http_/, '').gsub(/_/, '-')
      end
    end

  end
end

