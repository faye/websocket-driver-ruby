# encoding=utf-8

require "spec_helper"

describe WebSocket::Draft75Protocol do
  include EncodingHelper

  let :env do
    {
      "REQUEST_METHOD"  => "GET",
      "HTTP_CONNECTION" => "Upgrade",
      "HTTP_UPGRADE"    => "WebSocket",
      "HTTP_ORIGIN"     => "http://www.example.com"
    }
  end

  let :socket do
    socket = mock(WebSocket)
    socket.stub(:env).and_return(env)
    socket.stub(:url).and_return("ws://www.example.com/socket")
    socket.stub(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :protocol do
    protocol = WebSocket::Draft75Protocol.new(socket)
    protocol.onopen    { @open = true }
    protocol.onmessage { |message| @message += message }
    protocol.onclose   { @close = true }
    protocol
  end

  before do
    @open = @close = false
    @message = ""
  end

  describe "in the :connecting state" do
    it "starts in the :connecting state" do
      protocol.state.should == :connecting
    end

    describe :start do
      it "writes the handshake response to the socket" do
        socket.should_receive(:write).with(
            "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "WebSocket-Origin: http://www.example.com\r\n" +
            "WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        protocol.start
      end

      it "triggers the onopen event" do
        protocol.start
        @open.should == true
      end

      it "changes the state to :open" do
        protocol.start
        protocol.state.should == :open
      end

      it "sets the protocol version" do
        protocol.start
        protocol.version.should == "hixie-75"
      end
    end

    describe :frame do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.frame("Hello, world")
      end

      it "returns true" do
        protocol.frame("whatever").should == true
      end

      it "queues the frames until the handshake has been sent" do
        socket.should_receive(:write).with(
            "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "WebSocket-Origin: http://www.example.com\r\n" +
            "WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        socket.should_receive(:write).with("\x00Hi\xFF")

        protocol.frame("Hi")
        protocol.start

        @bytes.should == [0x00, 72, 105, 0xFF]
      end
    end
  end

  it_should_behave_like "draft-75 protocol"
end

