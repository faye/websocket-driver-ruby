# encoding=utf-8

require "spec_helper"

describe Faye::WebSocket::Draft76Parser do
  include EncodingHelper

  let :body do
    Faye::WebSocket.encode [0x91, 0x25, 0x3e, 0xd3, 0xa9, 0xe7, 0x6a, 0x88]
  end

  let :response do
    string = "\xB4\x9Cn@S\x04\x04&\xE5\e\xBFl\xB7\x9F\x1D\xF9"
    string.force_encoding("ASCII-8BIT") if string.respond_to?(:force_encoding)
    string
  end

  let :env do
    {
      "REQUEST_METHOD"          => "GET",
      "HTTP_CONNECTION"         => "Upgrade",
      "HTTP_UPGRADE"            => "WebSocket",
      "HTTP_ORIGIN"             => "http://www.example.com",
      "HTTP_SEC_WEBSOCKET_KEY1" => "1   38 wZ3f9 23O0 3l 0r",
      "HTTP_SEC_WEBSOCKET_KEY2" => "27   0E 6 2  1665:< ;U 1H",
      "rack.input"              => StringIO.new(body)
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
    parser = Faye::WebSocket::Draft76Parser.new(socket)
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
    it "starts in the connecting state" do
      parser.state.should == :connecting
    end

    describe :start do
      it "writes the handshake response to the socket" do
        socket.should_receive(:write).with(
            "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Origin: http://www.example.com\r\n" +
            "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        socket.should_receive(:write).with(response)
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
        parser.version.should == "hixie-76"
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
            "Sec-WebSocket-Origin: http://www.example.com\r\n" +
            "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        socket.should_receive(:write).with(response)
        socket.should_receive(:write).with("\x00Hi\xFF")

        parser.frame("Hi")
        parser.start

        @bytes.should == [0x00, 72, 105, 0xFF]
      end
    end

    describe "with no request body" do
      before { env.delete("rack.input") }

      describe :state do
        it "writes the handshake response with no body" do
          socket.should_receive(:write).with(
              "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
              "Upgrade: WebSocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Origin: http://www.example.com\r\n" +
              "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
              "\r\n")
          parser.start
        end

        it "does not trigger the onopen event" do
          parser.start
          @open.should == false
        end

        it "leaves the parser in the :connecting state" do
          parser.start
          parser.state.should == :connecting
        end

        describe "when the request body is received" do
          before { parser.start }

          it "sends the response body" do
            socket.should_receive(:write).with(response)
            parser.parse(body)
          end

          it "triggers the onopen event" do
            parser.parse(body)
            @open.should == true
          end

          it "changes the state to :open" do
            parser.parse(body)
            parser.state.should == :open
          end

          it "sends any frames queued before the handshake was complete" do
            socket.should_receive(:write).with(response)
            socket.should_receive(:write).with("\x00hello\xFF")
            parser.frame("hello")
            parser.parse(body)
            @bytes.should == [0, 104, 101, 108, 108, 111, 255]
          end
        end
      end
    end
  end

  it_should_behave_like "draft-75 parser"

  describe "in the :open state" do
    before { parser.start }

    describe :parse do
      it "closes the socket if a close frame is received" do
        parser.parse [0xFF, 0x00]
        @close.should == true
        parser.state.should == :closed
      end
    end

    describe :close do
      it "writes a close message to the socket" do
        frame = "\xFF\x00"
        frame.force_encoding("ASCII-8BIT") if frame.respond_to?(:force_encoding)
        socket.should_receive(:write).with(frame)
        parser.close
      end
    end
  end
end

