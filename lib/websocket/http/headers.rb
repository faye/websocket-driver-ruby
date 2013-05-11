module WebSocket
  module HTTP

    module Headers
      MAX_LINE_LENGTH = 4096
      CR = 0x0D
      LF = 0x0A

      HEADER_LINE = /^([!#\$%&'\*\+\-\.\^_`\|~0-9a-z]+):\s*((?:\t|[\x20-\x7e])*?)\s*$/i

      attr_reader :headers

      def initialize
        @buffer  = []
        @headers = {}
        @stage   = 0
      end

      def complete?
        @stage == 2
      end

      def error?
        @stage == -1
      end

      def parse(data)
        data.each_byte do |byte|
          if byte == LF and @stage < 2
            @buffer.pop if @buffer.last == CR
            if @buffer.empty?
              complete if @stage == 1
            else
              result = case @stage
                       when 0 then start_line(string_buffer)
                       when 1 then header_line(string_buffer)
                       end

              if result
                @stage = 1
              else
                error
              end
            end
            @buffer = []
          else
            @buffer << byte if @stage >= 0
            error if @stage < 2 and @buffer.size > MAX_LINE_LENGTH
          end
        end
        @env['rack.input'] = StringIO.new(string_buffer) if @env
      end

    private

      def complete
        @stage = 2
      end

      def error
        @stage = -1
      end

      def header_line(line)
        return false unless parsed = line.scan(HEADER_LINE).first
        @headers[HTTP.normalize_header(parsed[0])] = parsed[1].strip
        true
      end

      def string_buffer
        @buffer.pack('C*')
      end
    end

  end
end

