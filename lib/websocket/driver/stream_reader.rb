module WebSocket
  class Driver
    class StreamReader
      def initialize
        @buffer = Driver.encode('', :binary)
        @offset = 0
      end

      def put(buffer)
        return unless buffer and buffer.bytesize > 0
        @buffer << Driver.encode(buffer, :binary)
      end

      # Try to minimise the number of reallocations done:
      MINIMUM_AUTOMATIC_PRUNE_OFFSET = 128

      # Read bytes from the data:
      def read(length)
        return nil if (@offset + length) > @buffer.bytesize

        chunk = @buffer.byteslice(@offset, length)
        @offset += chunk.bytesize

        prune if @offset > MINIMUM_AUTOMATIC_PRUNE_OFFSET

        return chunk
      end

      def each_byte
        prune

        @buffer.each_byte do |value|
          @offset += 1
          yield value
        end
      end

    protected

      def prune
        buffer_size = @buffer.bytesize

        if @offset > buffer_size
          @buffer = Driver.encode('', :binary)
        else
          @buffer = @buffer.byteslice(@offset, buffer_size - @offset)
        end

        @offset = 0
      end

    end
  end
end
