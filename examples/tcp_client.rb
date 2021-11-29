require 'bundler/setup'
require 'websocket/driver'
require 'permessage_deflate'
require 'socket'
require 'uri'

class WSClient
  attr_reader :url, :thread

  def initialize(url)
    uri = URI.parse(url)

    @url  = url
    @tcp  = TCPSocket.new(uri.host, uri.port)
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
