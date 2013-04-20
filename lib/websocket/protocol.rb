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

module WebSocket
  root = File.expand_path('..', __FILE__)
  require root + '/../websocket_mask'

  def self.jruby?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
  end

  def self.rbx?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == 'rbx'
  end

  if jruby?
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

  autoload :Draft75Protocol, root + '/draft75_protocol'
  autoload :Draft76Protocol, root + '/draft76_protocol'
  autoload :HybiProtocol,    root + '/hybi_protocol'
  autoload :ClientProtocol,  root + '/client_protocol'

  class Protocol
    STATES = [:connecting, :open, :closing, :closed]

    class OpenEvent < Struct.new(nil) ; end
    class MessageEvent < Struct.new(:data) ; end
    class CloseEvent < Struct.new(:code, :reason) ; end

    attr_reader :protocol, :ready_state

    def initialize(socket, options = {})
      @socket      = socket
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

    def text(message)
      frame(message)
    end

    def binary(message)
      false
    end

    def ping(*args)
      false
    end

    def close
      return false unless @ready_state == 1
      @ready_state = 3
      dispatch(:onclose, CloseEvent.new(nil, nil))
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
      dispatch(:onopen, OpenEvent.new)
    end

    def dispatch(name, event)
      handler = __send__(name)
      handler.call(event) if handler
    end

    def queue(message)
      @queue << message
      true
    end

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
        HybiProtocol.new(socket, options)
      elsif env['HTTP_SEC_WEBSOCKET_KEY1']
        Draft76Protocol.new(socket, options)
      else
        Draft75Protocol.new(socket, options)
      end
    end

    def self.client(socket, options = {})
      ClientProtocol.new(socket, options.merge(:masking => true))
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

