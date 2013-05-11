module WebSocket
  class Driver

    class Headers
      ALLOWED_DUPLICATES = %w(set-cookie set-cookie2 warning www-authenticate)

      def initialize
        @sent  = Set.new
        @lines = []
      end

      def []=(name, value)
        return if value.nil?
        key = HTTP.normalize_header(name)
        return unless @sent.add?(key) or ALLOWED_DUPLICATES.include?(key)
        @lines << "#{name.strip}: #{value.to_s.strip}\r\n"
      end

      def to_s
        @lines.join('')
      end
    end

  end
end

