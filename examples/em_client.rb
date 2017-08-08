require 'bundler/setup'
require 'eventmachine'
require 'websocket/driver'
require 'permessage_deflate'

module Connection
  attr_accessor :url

  def connection_completed
    @driver = WebSocket::Driver.client(self)
    @driver.add_extension(PermessageDeflate)

    @driver.on :open do |event|
      @driver.text('Hello, world')
    end

    @driver.on :message do |event|
      p [:message, event.data]
    end

    @driver.on :close do |event|
      p [:close, event.code, event.reason]
      close_connection
    end

    @driver.start
  end

  def receive_data(data)
    @driver.parse(data)
  end

  def write(data)
    send_data(data)
  end
end

EM.run {
  url = ARGV.first
  uri = URI.parse(url)

  EM.connect(uri.host, uri.port, Connection) do |conn|
    conn.url = url
  end
}
