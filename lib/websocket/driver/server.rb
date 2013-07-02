module WebSocket
  class Driver

    class Server < Driver
      EVENTS = %w[open message error close]

      def initialize(socket, options = {})
        super
        @http = HTTP::Request.new
      end

      def env
        @http.complete? ? @http.env : nil
      end

      def url
        return nil unless e = env

        url  = "ws://#{e['HTTP_HOST']}"
        url << e['PATH_INFO']
        url << "?#{e['QUERY_STRING']}" unless e['QUERY_STRING'] == ''
        url
      end

      %w[set_header start state frame text binary ping close].each do |method|
        define_method(method) do |*args|
          if @delegate
            @delegate.__send__(method, *args)
          else
            @queue << [method, args]
            true
          end
        end
      end

      def parse(buffer)
        return @delegate.parse(buffer) if @delegate

        @http.parse(buffer)
        return fail_request('Invalid HTTP request') if @http.error?
        return unless @http.complete?

        @delegate = Driver.rack(self, @options)
        @delegate.on(:open) { open }
        EVENTS.each do |event|
          @delegate.on(event) { |e| emit(event, e) }
        end

        emit(:connect, ConnectEvent.new)
      end

      def write(data)
        @socket.write(Driver.encode(data, :binary))
      end

    private

      def fail_request
        emit(:error, ProtocolError.new(message))
        emit(:close, CloseEvent.new(Hybi::ERRORS[:protocol_error], message))
      end

      def open
        @queue.each do |message|
          @delegate.__send__(message[0], *message[1])
        end
        @queue = []
      end
    end

  end
end

