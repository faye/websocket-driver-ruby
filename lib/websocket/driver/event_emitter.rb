module WebSocket
  class Driver

    module EventEmitter
      def initialize
        @listeners = Hash.new { |h,k| h[k] = [] }
      end

      def add_listener(event, callable = nil, &block)
        listener = callable || block
        @listeners[event.to_s] << listener
        listener
      end

      def on(event, callable = nil, &block)
        if callable
          add_listener(event, callable)
        else
          add_listener(event, &block)
        end
      end

      def remove_listener(event, callable = nil, &block)
        listener = callable || block
        @listeners[event.to_s].delete(listener)
        listener
      end

      def remove_all_listeners(event = nil)
        if event
          @listeners.delete(event.to_s)
        else
          @listeners.clear
        end
      end

      def emit(event, *args)
        @listeners[event.to_s].dup.each do |listener|
          listener.call(*args)
        end

      rescue => error
        @emit_exception ||= error
      end

      def listener_count(event)
        return 0 unless @listeners.has_key?(event.to_s)
        @listeners[event.to_s].size
      end

      def listeners(event)
        @listeners[event.to_s]
      end

    private

      def reraise_emit_exception
        if @emit_exception
          error = @emit_exception
          @emit_exception = nil
          raise error
        end
      end
    end

  end
end
