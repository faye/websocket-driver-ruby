# Protocol references:
#
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-75
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
# * http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-17

require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'forwardable'
require 'net/http'
require 'stringio'
require 'uri'

module Faye
  class WebSocket

    class Parser
      def initialize(web_socket, options = {})
        @socket  = web_socket
        @options = options
        @role    = @socket.respond_to?(:env) ? :server : :client
      end

      def start
        return if @started
        case @role
        when :server then @socket.write(handshake_response)
        end
        @started = true
      end

      def dispatch(event, *args)
        handler = __send__(event)
        handler.call(*args) if handler
      end

      def onopen(&block)
        @onopen = block if block_given?
        @onopen
      end

      def onmessage(&block)
        @onmessage = block if block_given?
        @onmessage
      end

      def onerror(&block)
        @onerror = block if block_given?
        @onerror
      end

      def onclose(&block)
        @onclose = block if block_given?
        @onclose
      end
    end

    root = File.expand_path('..', __FILE__)
    require root + '/../../faye_websocket_mask'

    def self.jruby?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
    end

    def self.rbx?
      defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
    end

    if jruby?
      require 'jruby'
      com.jcoglan.faye.FayeWebsocketMaskService.new.basicLoad(JRuby.runtime)
    end

    unless WebSocketMask.respond_to?(:mask)
      def WebSocketMask.mask(payload, mask)
        @instance ||= new
        @instance.mask(payload, mask)
      end
    end

    unless String.instance_methods.include?(:force_encoding)
      require root + '/utf8_match'
    end

    autoload :Draft75Parser,   root + '/draft75_parser'
    autoload :Draft76Parser,   root + '/draft76_parser'
    autoload :HybiParser,      root + '/hybi_parser'

    def self.utf8_string(string)
      string = string.pack('C*') if Array === string
      string.respond_to?(:force_encoding) ?
          string.force_encoding('UTF-8') :
          string
    end

    def self.encode(string, validate_encoding = false)
      if Array === string
        string = utf8_string(string)
        return nil if validate_encoding and !valid_utf8?(string)
      end
      utf8_string(string)
    end

    def self.valid_utf8?(byte_array)
      string = utf8_string(byte_array)
      if defined?(UTF8_MATCH)
        UTF8_MATCH =~ string ? true : false
      else
        string.valid_encoding?
      end
    end

    def self.websocket?(env)
      connection = env['HTTP_CONNECTION'] || ''
      upgrade    = env['HTTP_UPGRADE']    || ''

      env['REQUEST_METHOD'] == 'GET' and
      connection.downcase.split(/\s*,\s*/).include?('upgrade') and
      upgrade.downcase == 'websocket'
    end

    def self.parser(env)
      if env['HTTP_SEC_WEBSOCKET_VERSION']
        HybiParser
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76Parser
      else
        Draft75Parser
      end
    end

    def self.determine_url(env)
      secure = if env.has_key?('HTTP_X_FORWARDED_PROTO')
                 env['HTTP_X_FORWARDED_PROTO'] == 'https'
               else
                 env['HTTP_ORIGIN'] =~ /^https:/i
               end

      scheme = secure ? 'wss:' : 'ws:'
      "#{ scheme }//#{ env['HTTP_HOST'] }#{ env['REQUEST_URI'] }"
    end

  end
end

