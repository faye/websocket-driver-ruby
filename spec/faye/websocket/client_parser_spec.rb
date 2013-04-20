require "spec_helper"

describe Faye::WebSocket::ClientParser do
  include EncodingHelper

  let :socket do
    socket = mock(Faye::WebSocket)
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

  let :parser do
    parser = Faye::WebSocket::ClientParser.new(socket, options)
    parser.onopen    { @open = true }
    parser.onmessage { |message| @message += message }
    parser.onclose   { |reason, code| @close = [code, reason] }
    parser
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
    Faye::WebSocket::ClientParser.stub(:generate_key).and_return(key)
    @open = @close = false
    @message = ""
  end

  describe "in the beginning state" do
    it "starts in no state" do
      parser.state.should == nil
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
        parser.start
      end

      it "returns true" do
        parser.start.should == true
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
          parser.start
        end
      end

      it "changes the state to :connecting" do
        parser.start
        parser.state.should == :connecting
      end
    end
  end

  describe "in the :connecting state" do
    before { parser.start }

    describe "with a valid response" do
      before { parser.parse(response) }

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        parser.state.should == :open
      end
    end

    describe "with a valid response followed by a frame" do
      before do
        resp = response + Faye::WebSocket.encode([0x81, 0x02, 72, 105])
        parser.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        parser.state.should == :open
      end

      it "parses the frame" do
        @message.should == "Hi"
      end
    end

    describe "with a bad Upgrade header" do
      before do
        resp = response.gsub(/websocket/, "wrong")
        parser.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [nil, nil]
        parser.state.should == :closed
      end
    end
 
    describe "with a bad Accept header" do
      before do
        resp = response.gsub(/QV3/, "wrong")
        parser.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [nil, nil]
        parser.state.should == :closed
      end
    end

    describe "with valid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: xmpp\r\n\r\n")
        parser.parse(resp)
      end

      it "changes the state to :open" do
        @open.should == true
        @close.should == false
        parser.state.should == :open
      end

      it "selects the subprotocol" do
        parser.protocol.should == "xmpp"
      end
    end

    describe "with invalid subprotocols" do
      let(:protocols) { ["foo", "xmpp"] }

      before do
        resp = response.gsub(/\r\n\r\n/, "\r\nSec-WebSocket-Protocol: irc\r\n\r\n")
        parser.parse(resp)
      end

      it "changes the state to :closed" do
        @open.should == false
        @close.should == [nil, nil]
        parser.state.should == :closed
      end

      it "selects no subprotocol" do
        parser.protocol.should == nil
      end
    end
  end
end

