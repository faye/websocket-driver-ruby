require "spec_helper"

describe WebSocket::Driver::Client do
  include EncodingHelper

  let :socket do
    socket = mock(WebSocket)
    socket.stub(:write) { |message| @bytes = bytes(message) }
    socket.stub(:url).and_return("ws://www.example.com/socket")
    socket
  end

  let :options do
    {:protocols => protocols}
  end

  let :protocols do
    nil
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
    WebSocket::Driver::Client.stub(:generate_key).and_return(key)
    @open = @error = @close = false
    @message = ""
  end

  describe "in the beginning state" do
    it "starts in no state" do
      driver.state.should == nil
    end

    describe :start do
      it "writes the handshake request to the socket" do
        socket.should_receive(:write).with(
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
        driver.start.should == true
      end

      describe "with subprotocols" do
        let(:protocols) { ["foo", "bar", "xmpp"] }

        it "writes the handshake with Sec-WebSocket-Protocol" do
          socket.should_receive(:write).with(
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

      describe "with custom headers" do
        before do
          driver.set_header "User-Agent", "Chrome"
        end

        it "writes the handshake with custom headers" do
          socket.should_receive(:write).with(
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
        driver.state.should == :connecting
      end
    end
  end

  describe "in the :connecting state" do
    before { driver.start }

    describe "with a valid response" do
      before { driver.parse(response) }

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        driver.state.should == :open
      end

      it "makes the response status available" do
        driver.status.should == 101
      end

      it "makes the response headers available" do
        driver.headers["Upgrade"].should == "websocket"
      end
    end

    describe "with a valid response followed by a frame" do
      before do
        resp = response + WebSocket::Driver.encode([0x81, 0x02, 72, 105])
        driver.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        driver.state.should == :open
      end

      it "parses the frame" do
        @message.should == "Hi"
      end
    end

    describe "with a bad status code" do
      before do
        resp = response.gsub(/101/, "4")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @error.message.should == "Error during WebSocket handshake: Invalid HTTP response"
        @close.should == [1002, "Error during WebSocket handshake: Invalid HTTP response"]
        driver.state.should == :closed
      end
    end

    describe "with a bad Upgrade header" do
      before do
        resp = response.gsub(/websocket/, "wrong")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @error.message.should == "Error during WebSocket handshake: 'Upgrade' header value is not 'WebSocket'"
        @close.should == [1002, "Error during WebSocket handshake: 'Upgrade' header value is not 'WebSocket'"]
        driver.state.should == :closed
      end
    end
 
    describe "with a bad Accept header" do
      before do
        resp = response.gsub(/QV3/, "wrong")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @error.message.should == "Error during WebSocket handshake: Sec-WebSocket-Accept mismatch"
        @close.should == [1002, "Error during WebSocket handshake: Sec-WebSocket-Accept mismatch"]
        driver.state.should == :closed
      end
    end

    describe "with valid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: xmpp\r\n\r\n")
        driver.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        driver.state.should == :open
      end

      it "selects the subprotocol" do
        driver.protocol.should == "xmpp"
      end
    end

    describe "with invalid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: irc\r\n\r\n")
        driver.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @error.message.should == "Error during WebSocket handshake: Sec-WebSocket-Protocol mismatch"
        @close.should == [1002, "Error during WebSocket handshake: Sec-WebSocket-Protocol mismatch"]
        driver.state.should == :closed
      end

      it "selects no subprotocol" do
        driver.protocol.should == nil
      end
    end
  end
end

