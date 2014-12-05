module WebSocket
  class Driver

    class Hybi
      class StreamReader
        def initialize
          @buffer = Driver.encode('', :binary)
        end

        def put(string)
          return unless string and string.bytesize > 0
          @buffer << Driver.encode(string, :binary)
        end

        def read(length)
          buffer_size = @buffer.bytesize
          return nil if length > buffer_size

          chunk   = @buffer.byteslice(0, length)
          @buffer = @buffer.byteslice(length, buffer_size - length)

          chunk
        end
      end
    end

  end
end
