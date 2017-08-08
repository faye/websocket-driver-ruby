class WSClient
  attr_reader :url

  def initialize(url)
    @url    = url
    @dead   = false
    @uri    = URI.parse(url)
    @driver = WebSocket::Driver.client(self)
    @tcp    = TCPSocket.new(@uri.host, @uri.scheme == "wss" || @uri.scheme == "ws" ? 80 : 443)
    @driver.add_extension(PermessageDeflate)

    @driver.on :open, ->(_e) { send "Hello world!" }
    @driver.on :message, ->(e) { puts "Received response #{e.data}" }
    @driver.start

    @thread = Thread.new do
      @driver.parse(@tcp.read(1)) until @dead
    end
  end

  def send(message)
    @driver.text(message)
  end

  def write(data)
    @tcp.write(data)
  end

  def close
    @driver.close
    @dead = true
    @thread.kill
  end
end
