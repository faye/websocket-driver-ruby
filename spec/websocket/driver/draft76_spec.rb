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
    socket = double(WebSocket)
    allow(socket).to receive(:env).and_return(env)
    allow(socket).to receive(:url).and_return("ws://www.example.com/socket")
    allow(socket).to receive(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :driver do
    driver = WebSocket::Driver::Draft76.new(socket)
    driver.on(:open)    { |e| @open = true }
    driver.on(:message) { |e| @message += e.data }
    driver.on(:error)   { |e| @error = e }
    driver.on(:close)   { |e| @close = true }
    driver
  end

  before do
    @open = @close = false
    @message = ""
  end

  describe "in the :connecting state" do
    it "starts in the connecting state" do
      expect(driver.state).to eq :connecting
    end

    describe :start do
      it "writes the handshake response to the socket" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 WebSocket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Origin: http://www.example.com\r\n" +
            "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(response)
        driver.start
      end

      it "returns true" do
        expect(driver.start).to eq true
      end

      it "triggers the onopen event" do
        driver.start
        expect(@open).to eq true
      end

      it "changes the state to :open" do
        driver.start
        expect(driver.state).to eq :open
      end

      it "sets the protocol version" do
        driver.start
        expect(driver.version).to eq "hixie-76"
      end

      describe "with an invalid key header" do
        before do
          env["HTTP_SEC_WEBSOCKET_KEY1"] = "2 L785 8o% s9Sy9@V. 4<1P5"
        end

        it "writes a handshake error response" do
          expect(socket).to receive(:write).with(
              "HTTP/1.1 400 Bad Request\r\n" +
              "Content-Type: text/plain\r\n" +
              "Content-Length: 45\r\n" +
              "\r\n" +
              "Client sent invalid Sec-WebSocket-Key headers")
          driver.start
        end

        it "does not trigger the onopen event" do
          driver.start
          expect(@open).to eq false
        end

        it "triggers the onerror event" do
          driver.start
          expect(@error.message).to eq "Client sent invalid Sec-WebSocket-Key headers"
        end

        it "triggers the onclose event" do
          driver.start
          expect(@close).to eq true
        end

        it "changes the state to closed" do
          driver.start
          expect(driver.state).to eq :closed
        end
      end
    end

    describe :frame do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.frame("Hello, world")
      end

      it "returns true" do
        expect(driver.frame("whatever")).to eq true
      end

      it "queues the frames until the handshake has been sent" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 WebSocket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Origin: http://www.example.com\r\n" +
            "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(response)
        expect(socket).to receive(:write).with(WebSocket::Driver.encode "\x00Hi\xFF", WebSocket::Driver::BINARY)

        driver.frame("Hi")
        driver.start

        expect(@bytes).to eq [0x00, 72, 105, 0xff]
      end
    end

    describe "with no request body" do
      before { env.delete("rack.input") }

      describe :start do
        it "writes the handshake response with no body" do
          expect(socket).to receive(:write).with(
              "HTTP/1.1 101 WebSocket Protocol Handshake\r\n" +
              "Upgrade: WebSocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Origin: http://www.example.com\r\n" +
              "Sec-WebSocket-Location: ws://www.example.com/socket\r\n" +
              "\r\n")
          driver.start
        end

        it "does not trigger the onopen event" do
          driver.start
          expect(@open).to eq false
        end

        it "leaves the protocol in the :connecting state" do
          driver.start
          expect(driver.state).to eq :connecting
        end

        describe "when the request body is received" do
          before { driver.start }

          it "sends the response body" do
            expect(socket).to receive(:write).with(response)
            driver.parse(body)
          end

          it "triggers the onopen event" do
            driver.parse(body)
            expect(@open).to eq true
          end

          it "changes the state to :open" do
            driver.parse(body)
            expect(driver.state).to eq :open
          end

          it "sends any frames queued before the handshake was complete" do
            expect(socket).to receive(:write).with(response)
            expect(socket).to receive(:write).with(WebSocket::Driver.encode "\x00hello\xFF", WebSocket::Driver::BINARY)
            driver.frame("hello")
            driver.parse(body)
            expect(@bytes).to eq [0, 104, 101, 108, 108, 111, 255]
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
        driver.parse [0xff, 0x00].pack("C*")
        expect(@close).to eq true
        expect(driver.state).to eq :closed
      end
    end

    describe :close do
      it "writes a close message to the socket" do
        driver.close
        expect(@bytes).to eq [0xff, 0x00]
      end
    end
  end
end
