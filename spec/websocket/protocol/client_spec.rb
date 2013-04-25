require "spec_helper"

describe WebSocket::Protocol::Client do
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

  let :protocol do
    protocol = WebSocket::Protocol::Client.new(socket, options)
    protocol.onopen    { |e| @open = true }
    protocol.onmessage { |e| @message += e.data }
    protocol.onclose   { |e| @close = [e.code, e.reason] }
    protocol
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
    WebSocket::Protocol::Client.stub(:generate_key).and_return(key)
    @open = @close = false
    @message = ""
  end

  describe "in the beginning state" do
    it "starts in no state" do
      protocol.state.should == nil
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
            "Origin: ws://www.example.com\r\n" +
            "\r\n")
        protocol.start
      end

      it "returns true" do
        protocol.start.should == true
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
              "Origin: ws://www.example.com\r\n" +
              "Sec-WebSocket-Protocol: foo, bar, xmpp\r\n" +
              "\r\n")
          protocol.start
        end
      end

      it "changes the state to :connecting" do
        protocol.start
        protocol.state.should == :connecting
      end
    end
  end

  describe "in the :connecting state" do
    before { protocol.start }

    describe "with a valid response" do
      before { protocol.parse(response) }

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        protocol.state.should == :open
      end
    end

    describe "with a valid response followed by a frame" do
      before do
        resp = response + WebSocket::Protocol.encode([0x81, 0x02, 72, 105])
        protocol.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        protocol.state.should == :open
      end

      it "parses the frame" do
        @message.should == "Hi"
      end
    end

    describe "with a bad Upgrade header" do
      before do
        resp = response.gsub(/websocket/, "wrong")
        protocol.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [1002, ""]
        protocol.state.should == :closed
      end
    end
 
    describe "with a bad Accept header" do
      before do
        resp = response.gsub(/QV3/, "wrong")
        protocol.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [1002, ""]
        protocol.state.should == :closed
      end
    end

    describe "with valid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: xmpp\r\n\r\n")
        protocol.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        protocol.state.should == :open
      end

      it "selects the subprotocol" do
        protocol.protocol.should == "xmpp"
      end
    end

    describe "with invalid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: irc\r\n\r\n")
        protocol.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [1002, ""]
        protocol.state.should == :closed
      end

      it "selects no subprotocol" do
        protocol.protocol.should == nil
      end
    end
  end
end

