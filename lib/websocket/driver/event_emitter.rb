module WebSocket
  class Driver

    module EventEmitter
      def initialize
        @listeners = Hash.new { |h,k| h[k] = [] }
      end

      def add_listener(event, &listener)
        @listeners[event.to_s] << listener
      end
      alias :on :add_listener

      def remove_listener(event, &listener)
        @listeners[event.to_s].delete(listener)
      end

      def remove_all_listeners(event = nil)
        if event
          @listeners.delete(event.to_s)
        else
          @listeners.clear
        end
      end

      def emit(event, *args)
        @listeners[event.to_s].each do |listener|
          listener.call(*args)
        end
      end
    end

  end
end

