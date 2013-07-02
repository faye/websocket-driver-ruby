# encoding=utf-8

require "spec_helper"

describe WebSocket::Driver::Draft76 do
  include EncodingHelper

  let :body do
    WebSocket::Driver.encode [0x91, 0x25, 0x3e, 0xd3, 0xa9, 0xe7, 0x6a, 0x88]
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
    socket = mock(WebSocket)
    socket.stub(:env).and_return(env)
    socket.stub(:url).and_return("ws://www.example.com/socket")
    socket.stub(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :driver do
    driver = WebSocket::Driver::Draft76.new(socket)
    driver.on(:open)    { |e| @open = true }
    driver.on(:message) { |e| @message += e.data }
    driver.on(:close)   { |e| @close = true }
    driver
  end

  before do
    @open = @close = false
    @message = ""
  end

  describe "in the :connecting state" do
    it "starts in the connecting state" do
      driver.state.should == :connecting
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
        driver.start
      end

      it "returns true" do
        driver.start.should == true
      end

      it "triggers the onopen event" do
        driver.start
        @open.should == true
      end

      it "changes the state to :open" do
        driver.start
        driver.state.should == :open
      end

      it "sets the protocol version" do
        driver.start
        driver.version.should == "hixie-76"
      end
    end

    describe :frame do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        driver.frame("Hello, world")
      end

      it "returns true" do
        driver.frame("whatever").should == true
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
        socket.should_receive(:write).with(WebSocket::Driver.encode "\x00Hi\xFF", :binary)

        driver.frame("Hi")
        driver.start

        @bytes.should == [0x00, 72, 105, 0xff]
      end
    end

    describe "with no request body" do
      before { env.delete("rack.input") }

      describe :start do
        it "writes the handshake response with no body" do
          socket.should_receive(:write).with(
              "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
              "Upgrade: WebSocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Origin: http://www.example.com\r\n" +
              "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
              "\r\n")
          driver.start
        end

        it "does not trigger the onopen event" do
          driver.start
          @open.should == false
        end

        it "leaves the protocol in the :connecting state" do
          driver.start
          driver.state.should == :connecting
        end

        describe "when the request body is received" do
          before { driver.start }

          it "sends the response body" do
            socket.should_receive(:write).with(response)
            driver.parse(body)
          end

          it "triggers the onopen event" do
            driver.parse(body)
            @open.should == true
          end

          it "changes the state to :open" do
            driver.parse(body)
            driver.state.should == :open
          end

          it "sends any frames queued before the handshake was complete" do
            socket.should_receive(:write).with(response)
            socket.should_receive(:write).with(WebSocket::Driver.encode "\x00hello\xFF", :binary)
            driver.frame("hello")
            driver.parse(body)
            @bytes.should == [0, 104, 101, 108, 108, 111, 255]
          end
        end
      end
    end
  end

  it_should_behave_like "draft-75 protocol"

  describe "in the :open state" do
    before { driver.start }

    describe :parse do
      it "closes the socket if a close frame is received" do
        driver.parse [0xff, 0x00]
        @close.should == true
        driver.state.should == :closed
      end
    end

    describe :close do
      it "writes a close message to the socket" do
        driver.close
        @bytes.should == [0xff, 0x00]
      end
    end
  end
end

