# Protocol references:
#
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-75
# * http://tools.ietf.org/html/draft-hixie-thewebsocketprotocol-76
# * http://tools.ietf.org/html/draft-ietf-hybi-thewebsocketprotocol-17

require 'base64'
require 'digest/md5'
require 'digest/sha1'
require 'set'
require 'stringio'
require 'uri'

module WebSocket
  autoload :HTTP, File.expand_path('../http', __FILE__)

  class Driver

    root = File.expand_path('../driver', __FILE__)
    require 'websocket_mask'

    if RUBY_PLATFORM =~ /java/
      require 'jruby'
      com.jcoglan.websocket.WebsocketMaskService.new.basicLoad(JRuby.runtime)
    end

    unless Mask.respond_to?(:mask)
      def Mask.mask(payload, mask)
        @instance ||= new
        @instance.mask(payload, mask)
      end
    end

    unless String.instance_methods.include?(:force_encoding)
      require root + '/utf8_match'
    end

    MAX_LENGTH = 0x3ffffff
    STATES     = [:connecting, :open, :closing, :closed]

    class ConnectEvent < Struct.new(nil) ; end
    class OpenEvent    < Struct.new(nil) ; end
    class MessageEvent < Struct.new(:data) ; end
    class CloseEvent   < Struct.new(:code, :reason) ; end

    class ProtocolError < StandardError ; end

    autoload :Client,       root + '/client'
    autoload :Draft75,      root + '/draft75'
    autoload :Draft76,      root + '/draft76'
    autoload :EventEmitter, root + '/event_emitter'
    autoload :Headers,      root + '/headers'
    autoload :Hybi,         root + '/hybi'
    autoload :Server,       root + '/server'

    include EventEmitter
    attr_reader :protocol, :ready_state

    def initialize(socket, options = {})
      super()

      @socket      = socket
      @options     = options
      @max_length  = options[:max_length] || MAX_LENGTH
      @headers     = Headers.new
      @queue       = []
      @ready_state = 0
    end

    def state
      return nil unless @ready_state >= 0
      STATES[@ready_state]
    end

    def set_header(name, value)
      return false unless @ready_state <= 0
      @headers[name] = value
      true
    end

    def start
      return false unless @ready_state == 0
      @socket.write(Driver.encode(handshake_response, :binary))
      open unless @stage == -1
      true
    end

    def text(message)
      frame(message)
    end

    def binary(message)
      false
    end

    def ping(*args)
      false
    end

    def close(reason = nil, code = nil)
      return false unless @ready_state == 1
      @ready_state = 3
      emit(:close, CloseEvent.new(nil, nil))
      true
    end

  private

    def open
      @ready_state = 1
      @queue.each { |message| frame(*message) }
      @queue = []
      emit(:open, OpenEvent.new)
    end

    def queue(message)
      @queue << message
      true
    end

    def self.client(socket, options = {})
      Client.new(socket, options.merge(:masking => true))
    end

    def self.server(socket, options = {})
      Server.new(socket, options.merge(:require_masking => true))
    end

    def self.rack(socket, options = {})
      env = socket.env
      if env['HTTP_SEC_WEBSOCKET_VERSION']
        Hybi.new(socket, options.merge(:require_masking => true))
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76.new(socket, options)
      else
        Draft75.new(socket, options)
      end
    end

    def self.encode(string, encoding = nil)
      if Array === string
        string = string.pack('C*')
        encoding ||= :binary
      else
        encoding ||= :utf8
      end
      case encoding
      when :binary
        string.force_encoding('ASCII-8BIT') if string.respond_to?(:force_encoding)
      when :utf8
        string.force_encoding('UTF-8') if string.respond_to?(:force_encoding)
        return nil unless valid_utf8?(string)
      end
      string
    end

    def self.utf8_string(string)
      string = string.pack('C*') if Array === string
      string.respond_to?(:force_encoding) ?
          string.force_encoding('UTF-8') :
          string
    end

    def self.valid_utf8?(string)
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
