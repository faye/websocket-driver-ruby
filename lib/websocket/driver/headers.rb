module WebSocket
  class Driver

    class Headers
      ALLOWED_DUPLICATES = %w[set-cookie set-cookie2 warning www-authenticate]

      def initialize(received = {})
        @raw = received
        clear

        @received = {}
        @raw.each { |k,v| @received[HTTP.normalize_header(k)] = v }
      end

      def clear
        @sent  = Set.new
        @headers = {}
      end

      def [](name)
        @received[HTTP.normalize_header(name)]
      end

      def []=(name, value)
        return if value.nil?
        key = HTTP.normalize_header(name)
        return unless @sent.add?(key) or ALLOWED_DUPLICATES.include?(key)

        header = name.strip
        unless @headers.include? header
          @headers[header] = []
        end

        @headers[header] << value.to_s.strip
      end

      def headers_set
        @headers
      end

      def inspect
        @raw.inspect
      end

      def to_h
        @raw.dup
      end

      def merge(other)
        other.headers_set.each {|key, value|
          if value.is_a? Array
            value.each {|v| self[key] = v }
          else
            self[key] = value
          end
        }

        self
      end

      def to_s
        @headers.flat_map {|header, values|
          values.map {|value|
            "#{ header.strip }: #{ value.to_s.strip }\r\n"
          }
        }.join('')
      end
    end

  end
end
