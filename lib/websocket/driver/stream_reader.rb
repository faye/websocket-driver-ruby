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
      
      # Read bytes from the data:
      def read(length)
        return nil if (@offset + length) > @buffer.bytesize
        
        chunk = @buffer.byteslice(@offset, length)
        @offset += chunk.bytesize
        
        prune
        
        return chunk
      end
      
      def each_byte
        prune(true)
        
        @buffer.each_byte do |value|
          @offset += 1
          yield value
        end
      end
      
    protected
      
      def prune(force = false)
        # only prune if forced or we have a significant amount to cut.
        return unless force or @offset > 128
        
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
