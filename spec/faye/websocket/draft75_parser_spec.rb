# encoding=utf-8

require "spec_helper"

describe Faye::WebSocket::Draft75Parser do
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
    socket = mock(Faye::WebSocket)
    socket.stub(:env).and_return(env)
    socket.stub(:url).and_return("ws://www.example.com/socket")
    socket.stub(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :parser do
    parser = Faye::WebSocket::Draft75Parser.new(socket)
    parser.onopen    { @open = true }
    parser.onmessage { |message| @message += message }
    parser.onclose   { @close = true }
    parser
  end

  before do
    @open = @close = false
    @message = ""
  end

  describe "in the :connecting state" do
    it "starts in the :connecting state" do
      parser.state.should == :connecting
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
        parser.start
      end

      it "triggers the onopen event" do
        parser.start
        @open.should == true
      end

      it "changes the state to :open" do
        parser.start
        parser.state.should == :open
      end

      it "sets the protocol version" do
        parser.start
        parser.version.should == "hixie-75"
      end
    end

    describe :frame do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        parser.frame("Hello, world")
      end

      it "returns true" do
        parser.frame("whatever").should == true
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

        parser.frame("Hi")
        parser.start

        @bytes.should == [0x00, 72, 105, 0xFF]
      end
    end
  end

  it_should_behave_like "draft-75 parser"
end

