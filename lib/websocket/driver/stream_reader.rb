module WebSocket
  class Driver

    class StreamReader
      MAX_CAPACITY = 0xfffffff

      def initialize
        @queue    = []
        @capacity = 0
        @cursor   = 0
      end

      def push(chunk)
        if chunk.bytesize > MAX_CAPACITY - @capacity
          return false
        end

        @queue << chunk.force_encoding(BINARY)
        @capacity += chunk.bytesize

        true
      end

      def read(length)
        return nil if @capacity < length

        target = ("\0" * length).force_encoding(BINARY)
        offset = 0

        while offset < length
          chunk = @queue.first

          available  = chunk.bytesize - @cursor
          required   = length - offset
          take_bytes = (available < required) ? available : required

          target[offset ... offset + take_bytes] = chunk[@cursor ... @cursor + take_bytes]
          offset += take_bytes
          @capacity -= take_bytes

          if take_bytes == available
            @cursor = 0
            @queue.shift
          else
            @cursor += take_bytes
          end
        end

        target
      end

      def each_byte
        until @queue.empty?
          chunk = @queue.first
          (@cursor ... chunk.bytesize).each do |i|
            @cursor += 1
            yield chunk.getbyte(i)
          end
          @cursor = 0
          @queue.shift
        end
      end
    end

  end
end
