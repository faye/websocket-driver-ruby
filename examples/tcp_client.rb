require 'bundler/setup'
require 'websocket/driver'
require 'permessage_deflate'
require 'socket'
require 'uri'

class WSClient
  DEFAULT_PORTS = {'ws' => 80, 'wss' => 443}

  attr_reader :url, :thread

  def initialize(url)
    @url  = url
    @uri  = URI.parse(url)
    @port = @uri.port || DEFAULT_PORTS[@uri.scheme]

    @tcp  = TCPSocket.new(@uri.host, @port)
    @dead = false

    @driver = WebSocket::Driver.client(self)
    @driver.add_extension(PermessageDeflate)

    @driver.on(:open)    { |event| send "Hello world!" }
    @driver.on(:message) { |event| p [:message, event.data] }
    @driver.on(:close)   { |event| finalize(event) }

    @thread = Thread.new do
      @driver.parse(@tcp.read(1)) until @dead
    end

    @driver.start
  end

  def send(message)
    @driver.text(message)
  end

  def write(data)
    @tcp.write(data)
  end

  def close
    @driver.close
  end

  def finalize(event)
    p [:close, event.code, event.reason]
    @dead = true
    @thread.kill
  end
end

ws = WSClient.new(ARGV.first)
ws.thread.join
