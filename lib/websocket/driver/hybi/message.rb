module WebSocket
  class Driver
    class Hybi

      class Message
        attr_accessor :data, :frames

        def initialize
          @data   = ''
          @frames = []
        end

        def <<(frame)
          @data   << frame.payload
          @frames << frame
        end
      end

    end
  end
end
