require 'bundler/setup'
require 'eventmachine'
require 'websocket/driver'
require 'permessage_deflate'

module Connection
  attr_accessor :url

  def connection_completed
    @driver = WebSocket::Driver.client(self)
    @driver.add_extension(PermessageDeflate)

    @driver.on(:open)    { |event| @driver.text('Hello, world') }
    @driver.on(:message) { |event| p [:message, event.data] }
    @driver.on(:close)   { |event| finalize(event) }

    @driver.start
  end

  def receive_data(data)
    @driver.parse(data)
  end

  def write(data)
    send_data(data)
  end

  def finalize(event)
    p [:close, event.code, event.reason]
    close_connection
  end
end

EM.run {
  url = ARGV.first
  uri = URI.parse(url)

  EM.connect(uri.host, uri.port, Connection) do |conn|
    conn.url = url
  end
}
