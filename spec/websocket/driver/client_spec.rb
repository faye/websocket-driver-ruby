require "spec_helper"

describe WebSocket::Driver::Client do
  include EncodingHelper

  let :socket do
    socket = double(WebSocket)
    allow(socket).to receive(:write) { |message| @bytes = bytes(message) }
    allow(socket).to receive(:url).and_return(url)
    socket
  end

  let :options do
    { :protocols => protocols }
  end

  let :protocols do
    nil
  end

  let :url do
    "ws://www.example.com/socket"
  end

  let :driver do
    driver = WebSocket::Driver::Client.new(socket, options)
    driver.on(:open)    { |e| @open = true }
    driver.on(:message) { |e| @message += e.data }
    driver.on(:error)   { |e| @error = e }
    driver.on(:close)   { |e| @close = [e.code, e.reason] }
    driver
  end

  let :key do
    "2vBVWg4Qyk3ZoM/5d3QD9Q=="
  end

  let :response do
    "HTTP/1.1 101 Switching Protocols\r\n" +
    "Upgrade: websocket\r\n" +
    "Connection: Upgrade\r\n" +
    "Sec-WebSocket-Accept: QV3I5XUXU2CdhtjixE7QCkCcMZM=\r\n" +
    "\r\n"
  end

  before do
    allow(WebSocket::Driver::Client).to receive(:generate_key).and_return(key)
    @open = @error = @close = false
    @message = ""
  end

  describe "in the beginning state" do
    it "starts in no state" do
      expect(driver.state).to eq nil
    end

    describe :close do
      it "changes the state to :closed" do
        driver.close
        expect(driver.state).to eq :closed
        expect(@close).to eq [1000, ""]
      end
    end

    describe :start do
      it "writes the handshake request to the socket" do
        expect(socket).to receive(:write).with(
            "GET /socket HTTP/1.1\r\n" +
            "Host: www.example.com\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
            "Sec-WebSocket-Version: 13\r\n" +
            "\r\n")
        driver.start
      end

      it "returns true" do
        expect(driver.start).to eq true
      end

      describe "with subprotocols" do
        let(:protocols) { ["foo", "bar", "xmpp"] }

        it "writes the handshake with Sec-WebSocket-Protocol" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "Sec-WebSocket-Protocol: foo, bar, xmpp\r\n" +
              "\r\n")
          driver.start
        end
      end

      describe "with basic auth" do
        let(:url) { "ws://user:pass@www.example.com/socket" }

        it "writes the handshake with Sec-WebSocket-Protocol" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "Authorization: Basic dXNlcjpwYXNz\r\n" +
              "\r\n")
          driver.start
        end
      end

      describe "with an invalid URL" do
        let(:url) { "stream.wikimedia.org/rc" }

        it "throws an URIError error" do
          expect { driver }.to raise_error(WebSocket::Driver::URIError)
        end
      end

      describe "with an explicit port" do
        let(:url) { "ws://www.example.com:3000/socket" }

        it "includes the port in the Host header" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com:3000\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "\r\n")
          driver.start
        end
      end

      describe "with a wss: URL" do
        let(:url) { "wss://www.example.com/socket" }

        it "does not include the port in the Host header" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "\r\n")
          driver.start
        end
      end

      describe "with a wss: URL and explicit port" do
        let(:url) { "wss://www.example.com:3000/socket" }

        it "includes the port in the Host header" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com:3000\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "\r\n")
          driver.start
        end
      end

      describe "with custom headers" do
        before do
          driver.set_header "User-Agent", "Chrome"
        end

        it "writes the handshake with custom headers" do
          expect(socket).to receive(:write).with(
              "GET /socket HTTP/1.1\r\n" +
              "Host: www.example.com\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Key: 2vBVWg4Qyk3ZoM/5d3QD9Q==\r\n" +
              "Sec-WebSocket-Version: 13\r\n" +
              "User-Agent: Chrome\r\n" +
              "\r\n")
          driver.start
        end
      end

      it "changes the state to :connecting" do
        driver.start
        expect(driver.state).to eq :connecting
      end
    end
  end

  describe "using a proxy" do
    it "sends a CONNECT request" do
      proxy = driver.proxy("http://proxy.example.com")
      expect(socket).to receive(:write).with(
          "CONNECT www.example.com:80 HTTP/1.1\r\n" +
          "Host: www.example.com\r\n" +
          "Connection: keep-alive\r\n" +
          "Proxy-Connection: keep-alive\r\n" +
          "\r\n")
      proxy.start
    end

    it "sends an authenticated CONNECT request" do
      proxy = driver.proxy("http://user:pass@proxy.example.com")
      expect(socket).to receive(:write).with(
          "CONNECT www.example.com:80 HTTP/1.1\r\n" +
          "Host: www.example.com\r\n" +
          "Connection: keep-alive\r\n" +
          "Proxy-Connection: keep-alive\r\n" +
          "Proxy-Authorization: Basic dXNlcjpwYXNz\r\n" +
          "\r\n")
      proxy.start
    end

    it "sends a CONNECT request with custom headers" do
      proxy = driver.proxy("http://proxy.example.com")
      proxy.set_header("User-Agent", "Chrome")
      expect(socket).to receive(:write).with(
          "CONNECT www.example.com:80 HTTP/1.1\r\n" +
          "Host: www.example.com\r\n" +
          "Connection: keep-alive\r\n" +
          "Proxy-Connection: keep-alive\r\n" +
          "User-Agent: Chrome\r\n" +
          "\r\n")
      proxy.start
    end

    describe "receiving a response" do
      let(:proxy) { driver.proxy("http://proxy.example.com") }

      before do
        @connect = nil
        proxy.on(:connect) { @connect = true }
        proxy.on(:error)   { |e| @error = e }
      end

      it "emits a 'connect' event when the proxy connects" do
        proxy.parse("HTTP/1.1 200 OK\r\n\r\n")
        expect(@connect).to eq true
        expect(@error).to eq false
      end

      it "emits an 'error' event if the proxy does not connect" do
        proxy.parse("HTTP/1.1 403 Forbidden\r\n\r\n")
        expect(@connect).to eq nil
        expect(@error.message).to eq "Can't establish a connection to the server at ws://www.example.com/socket"
      end
    end
  end

  describe "in the :connecting state" do
    before { driver.start }

    describe "with a valid response" do
      before { driver.parse(response) }

      it "changes the state to :open" do
        expect(@open).to eq true
        expect(@close).to eq false
        expect(driver.state).to eq :open
      end

      it "makes the response status available" do
        expect(driver.status).to eq 101
      end

      it "makes the response headers available" do
        expect(driver.headers["Upgrade"]).to eq "websocket"
      end
    end

    describe "with a valid response followed by a frame" do
      before do
        resp = response + encode([0x81, 0x02, 72, 105])
        driver.parse(resp)
      end

      it "changes the state to :open" do
        expect(@open).to eq true
        expect(@close).to eq false
        expect(driver.state).to eq :open
      end

      it "parses the frame" do
        expect(@message).to eq "Hi"
      end
    end

    describe "with a bad status code" do
      before do
        resp = response.gsub(/101/, "4")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        expect(@open).to eq false
        expect(@error.message).to eq "Error during WebSocket handshake: Invalid HTTP response"
        expect(@close).to eq [1002, "Error during WebSocket handshake: Invalid HTTP response"]
        expect(driver.state).to eq :closed
      end
    end

    describe "with a bad Upgrade header" do
      before do
        resp = response.gsub(/websocket/, "wrong")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        expect(@open).to eq false
        expect(@error.message).to eq "Error during WebSocket handshake: 'Upgrade' header value is not 'WebSocket'"
        expect(@close).to eq [1002, "Error during WebSocket handshake: 'Upgrade' header value is not 'WebSocket'"]
        expect(driver.state).to eq :closed
      end
    end

    describe "with a bad Accept header" do
      before do
        resp = response.gsub(/QV3/, "wrong")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        expect(@open).to eq false
        expect(@error.message).to eq "Error during WebSocket handshake: Sec-WebSocket-Accept mismatch"
        expect(@close).to eq [1002, "Error during WebSocket handshake: Sec-WebSocket-Accept mismatch"]
        expect(driver.state).to eq :closed
      end
    end

    describe "with valid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: xmpp\r\n\r\n")
        driver.parse(resp)
      end

      it "changes the state to :open" do
        expect(@open).to eq true
        expect(@close).to eq false
        expect(driver.state).to eq :open
      end

      it "selects the subprotocol" do
        expect(driver.protocol).to eq "xmpp"
      end
    end

    describe "with invalid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: irc\r\n\r\n")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        expect(@open).to eq false
        expect(@error.message).to eq "Error during WebSocket handshake: Sec-WebSocket-Protocol mismatch"
        expect(@close).to eq [1002, "Error during WebSocket handshake: Sec-WebSocket-Protocol mismatch"]
        expect(driver.state).to eq :closed
      end

      it "selects no subprotocol" do
        expect(driver.protocol).to eq nil
      end
    end
  end
end
