module WebSocket
  module HTTP

    class Response
      include Headers

      STATUS_LINE = /^(HTTP\/[0-9]\.[0-9])\s+([0-9]{3})\s(.*)$/

      attr_reader :code

      def on_line(line)
        return super if @stage == 1
        return error unless parsed = line.scan(STATUS_LINE).first
        @code = parsed[1].to_i
        @stage = 1
      end
    end

  end
end

