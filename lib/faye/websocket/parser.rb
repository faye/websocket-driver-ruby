# Protocol references:
#
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-75
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
# * http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-17

require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'net/http'
require 'stringio'
require 'uri'

module Faye
  class WebSocket

    class Parser
      STATES = [:connecting, :open, :closing, :closed]

      attr_reader :protocol, :ready_state

      def initialize(web_socket, options = {})
        @socket      = web_socket
        @options     = options
        @queue       = []
        @ready_state = 0
      end

      def state
        return nil unless @ready_state >= 0
        STATES[@ready_state]
      end

      def start
        return false unless @ready_state == 0
        @socket.write(handshake_response)
        open unless @stage == -1
        true
      end

      def ping(*args)
        false
      end

      def close
        return false unless @ready_state == 1
        @ready_state = 3
        dispatch(:onclose)
        true
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

    private

      def open
        @ready_state = 1
        @queue.each { |message| frame(*message) }
        @queue = []
        dispatch(:onopen)
      end

      def dispatch(event, *args)
        handler = __send__(event)
        handler.call(*args) if handler
      end

      def queue(message)
        @queue << message
        true
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
    autoload :ClientParser,    root + '/client_parser'

    def self.encode(string, validate_encoding = false)
      if Array === string
        string = utf8_string(string)
        return nil if validate_encoding and !valid_utf8?(string)
      end
      utf8_string(string)
    end

    def self.server(socket, options = {})
      env = socket.env
      if env['HTTP_SEC_WEBSOCKET_VERSION']
        HybiParser.new(socket, options)
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76Parser.new(socket, options)
      else
        Draft75Parser.new(socket, options)
      end
    end

    def self.client(socket, options = {})
      ClientParser.new(socket, options.merge(:masking => true))
    end

    def self.utf8_string(string)
      string = string.pack('C*') if Array === string
      string.respond_to?(:force_encoding) ?
          string.force_encoding('UTF-8') :
          string
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

  end
end

