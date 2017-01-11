# encoding=utf-8

shared_examples_for "hybi driver" do
  include EncodingHelper

  let :env do
    {
      "REQUEST_METHOD"                => "GET",
      "HTTP_CONNECTION"               => "Upgrade",
      "HTTP_UPGRADE"                  => "websocket",
      "HTTP_ORIGIN"                   => "http://www.example.com",
#      "HTTP_SEC_WEBSOCKET_EXTENSIONS" => "x-webkit-deflate-frame",
      "HTTP_SEC_WEBSOCKET_KEY"        => "JFBCWHksyIpXV+6Wlq/9pw==",
      "HTTP_SEC_WEBSOCKET_VERSION"    => "13"
    }
  end

  let :options do
    {:masking => false, :parser_class => parser_class, :unparser_class => unparser_class}
  end

  let :socket do
    socket = double(WebSocket)
    allow(socket).to receive(:env).and_return(env)
    allow(socket).to receive(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :driver do
    driver = create_driver
    driver.on :open, -> e { @open = true }
    driver.on(:message) { |e| @message += e.data }
    driver.on(:error)   { |e| @error = e }
    driver.on(:close)   { |e| @close = [e.code, e.reason] }
    driver
  end

  before do
    @open = @error = @close = false
    @message = ""
  end

  describe "in the :connecting state" do
    it "starts in the :connecting state" do
      expect(driver.state).to eq :connecting
    end

    describe :start do
      it "writes the handshake response to the socket" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        driver.start
      end

      it "returns true" do
        expect(driver.start).to eq true
      end

      describe "with subprotocols" do
        before do
          env["HTTP_SEC_WEBSOCKET_PROTOCOL"] = "foo, bar, xmpp"
          options[:protocols] = ["xmpp"]
        end

        it "writes the handshake with Sec-WebSocket-Protocol" do
          expect(socket).to receive(:write).with(
              "HTTP/1.1 101 Switching Protocols\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
              "Sec-WebSocket-Protocol: xmpp\r\n" +
              "\r\n")
          driver.start
        end

        it "sets the subprotocol" do
          driver.start
          expect(driver.protocol).to eq "xmpp"
        end
      end

      describe "with invalid extensions" do
        before do
          env["HTTP_SEC_WEBSOCKET_EXTENSIONS"] = "x-webkit- -frame"
        end

        it "does not write a handshake" do
          expect(socket).not_to receive(:write)
          driver.start
        end

        it "does not trigger the onopen event" do
          driver.start
          expect(@open).to eq false
        end

        it "triggers the onerror event" do
          driver.start
          expect(@error.message).to eq "Invalid Sec-WebSocket-Extensions header: x-webkit- -frame"
        end

        it "triggers the onclose event" do
          driver.start
          expect(@close).to eq [1002, "Invalid Sec-WebSocket-Extensions header: x-webkit- -frame"]
        end

        it "changes the state to :closed" do
          driver.start
          expect(driver.state).to eq :closed
        end
      end

      describe "with custom headers" do
        before do
          driver.set_header "Authorization", "Bearer WAT"
        end

        it "writes the handshake with custom headers" do
          expect(socket).to receive(:write).with(
              "HTTP/1.1 101 Switching Protocols\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
              "Authorization: Bearer WAT\r\n" +
              "\r\n")
          driver.start
        end
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
        expect(driver.version).to eq "hybi-13"
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
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(WebSocket::Driver.encode [0x81, 0x02, 72, 105])

        driver.frame("Hi")
        driver.start
      end
    end

    describe :ping do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.ping
      end

      it "returns true" do
        expect(driver.ping).to eq true
      end

      it "queues the ping until the handshake has been sent" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(WebSocket::Driver.encode [0x89, 0])

        driver.ping
        driver.start
      end
    end

    describe :pong do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.pong
      end

      it "returns true" do
        expect(driver.pong).to eq true
      end

      it "queues the pong until the handshake has been sent" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(WebSocket::Driver.encode [0x8a, 0])

        driver.pong
        driver.start
      end
    end

    describe :close do
      it "does not write anything to the socket" do
        expect(socket).not_to receive(:write)
        driver.close
      end

      it "returns true" do
        expect(driver.close).to eq true
      end

      it "triggers the onclose event" do
        driver.close
        expect(@close).to eq [1000, ""]
      end

      it "changes the state to :closed" do
        driver.close
        expect(driver.state).to eq :closed
      end
    end
  end

  describe "in the :open state" do
    before { driver.start }

    describe :parse do
      let(:mask) { (1..4).map { rand 255 } }

      def mask_message(*bytes)
        output = []
        bytes.each_with_index do |byte, i|
          output[i] = byte ^ mask[i % 4]
        end
        output
      end

      it "parses unmasked text frames" do
        driver.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f].pack("C*")
        expect(@message).to eq "Hello"
      end

      it "parses multiple frames from the same packet" do
        driver.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f].pack("C*")
        expect(@message).to eq "HelloHello"
      end

      it "parses empty text frames" do
        driver.parse [0x81, 0x00].pack("C*")
        expect(@message).to eq ""
      end

      it "parses fragmented text frames" do
        driver.parse [0x01, 0x03, 0x48, 0x65, 0x6c].pack("C*")
        driver.parse [0x80, 0x02, 0x6c, 0x6f].pack("C*")
        expect(@message).to eq "Hello"
      end

      it "parses masked text frames" do
        driver.parse ([0x81, 0x85] + mask + mask_message(0x48, 0x65, 0x6c, 0x6c, 0x6f)).pack("C*")
        expect(@message).to eq "Hello"
      end

      it "parses masked empty text frames" do
        driver.parse ([0x81, 0x80] + mask + mask_message()).pack("C*")
        expect(@message).to eq ""
      end

      it "parses masked fragmented text frames" do
        driver.parse ([0x01, 0x81] + mask + mask_message(0x48)).pack("C*")
        driver.parse ([0x80, 0x84] + mask + mask_message(0x65, 0x6c, 0x6c, 0x6f)).pack("C*")
        expect(@message).to eq "Hello"
      end

      it "closes the socket if the frame has an unrecognized opcode" do
        driver.parse [0x83, 0x00].pack("C*")
        expect(@bytes[0..3]).to eq [0x88, 0x1e, 0x03, 0xea]
        expect(@error.message).to eq "Unrecognized frame opcode: 3"
        expect(@close).to eq [1002, "Unrecognized frame opcode: 3"]
        expect(driver.state).to eq :closed
      end

      it "closes the socket if a close frame is received" do
        driver.parse [0x88, 0x07, 0x03, 0xe8, 0x48, 0x65, 0x6c, 0x6c, 0x6f].pack("C*")
        expect(@bytes).to eq [0x88, 0x07, 0x03, 0xe8, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        expect(@close).to eq [1000, "Hello"]
        expect(driver.state).to eq :closed
      end

      it "parses unmasked multibyte text frames" do
        driver.parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf].pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses frames received in several packets" do
        driver.parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c].pack("C*")
        driver.parse [0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf].pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses fragmented multibyte text frames" do
        driver.parse [0x01, 0x0a, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3].pack("C*")
        driver.parse [0x80, 0x01, 0xbf].pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses masked multibyte text frames" do
        driver.parse ([0x81, 0x8b] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf)).pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses masked fragmented multibyte text frames" do
        driver.parse ([0x01, 0x8a] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3)).pack("C*")
        driver.parse ([0x80, 0x81] + mask + mask_message(0xbf)).pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses unmasked medium-length text frames" do
        driver.parse ([0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40).pack("C*")
        expect(@message).to eq "Hello" * 40
      end

      it "returns an error for too-large frames" do
        driver.parse [0x81, 0x7f, 0x00, 0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00].pack("C*")
        expect(@error.message).to eq "WebSocket frame length too large"
        expect(@close).to eq [1009, "WebSocket frame length too large"]
        expect(driver.state).to eq :closed
      end

      it "parses masked medium-length text frames" do
        driver.parse ([0x81, 0xfe, 0x00, 0xc8] + mask + mask_message(*([0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40))).pack("C*")
        expect(@message).to eq "Hello" * 40
      end

      it "replies to pings with a pong" do
        driver.parse [0x89, 0x04, 0x4f, 0x48, 0x41, 0x49].pack("C*")
        expect(@bytes).to eq [0x8a, 0x04, 0x4f, 0x48, 0x41, 0x49]
      end

      describe "when a message listener raises an error" do
        before do
          @messages = []

          driver.on :message do |msg|
            @messages << msg.data
            raise "an error"
          end
        end

        it "is not trapped by the parser" do
          buffer = [0x81, 0x02, 0x48, 0x65].pack('C*')
          expect { driver.parse buffer }.to raise_error(RuntimeError, "an error")
        end

        it "parses unmasked text frames without dropping input" do
          driver.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x81, 0x05].pack("C*") rescue nil
          driver.parse [0x57, 0x6f, 0x72, 0x6c, 0x64].pack("C*") rescue nil
          expect(@messages).to eq(["Hello", "World"])
        end
      end
    end

    describe :frame do
      it "formats the given string as a WebSocket frame" do
        driver.frame "Hello"
        expect(@bytes).to eq [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      end

      it "formats a byte array as a binary WebSocket frame" do
        driver.frame [0x48, 0x65, 0x6c]
        expect(@bytes).to eq [0x82, 0x03, 0x48, 0x65, 0x6c]
      end

      it "encodes multibyte characters correctly" do
        message = encode "Apple = "
        driver.frame message
        expect(@bytes).to eq [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
      end

      it "encodes medium-length strings using extra length bytes" do
        message = "Hello" * 40
        driver.frame message
        expect(@bytes).to eq [0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40
      end

      it "encodes close frames with an error code" do
        driver.frame "Hello", :close, 1002
        expect(@bytes).to eq [0x88, 0x07, 0x03, 0xea, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      end

      it "encodes pong frames" do
        driver.frame "", :pong
        expect(@bytes).to eq [0x8a, 0x00]
      end
    end

    describe :ping do
      before do
        @reply = nil
      end

      it "writes a ping frame to the socket" do
        driver.ping("mic check")
        expect(@bytes).to eq [0x89, 0x09, 0x6d, 0x69, 0x63, 0x20, 0x63, 0x68, 0x65, 0x63, 0x6b]
      end

      it "returns true" do
        expect(driver.ping).to eq true
      end

      it "runs the given callback on matching pong" do
        driver.ping("Hi") { @reply = true }
        driver.parse [0x8a, 0x02, 72, 105].pack("C*")
        expect(@reply).to eq true
      end

      it "does not run the callback on non-matching pong" do
        driver.ping("Hi") { @reply = true }
        driver.parse [0x8a, 0x03, 119, 97, 116].pack("C*")
        expect(@reply).to eq nil
      end
    end

    describe :pong do
      it "writes a pong frame to the socket" do
        driver.pong("mic check")
        expect(@bytes).to eq [0x8a, 0x09, 0x6d, 0x69, 0x63, 0x20, 0x63, 0x68, 0x65, 0x63, 0x6b]
      end

      it "returns true" do
        expect(driver.pong).to eq true
      end
    end

    describe :close do
      it "writes a close frame to the socket" do
        driver.close("<%= reasons %>", 1003)
        expect(@bytes).to eq [0x88, 0x10, 0x03, 0xeb, 0x3c, 0x25, 0x3d, 0x20, 0x72, 0x65, 0x61, 0x73, 0x6f, 0x6e, 0x73, 0x20, 0x25, 0x3e]
      end

      it "returns true" do
        expect(driver.close).to eq true
      end

      it "does not trigger the onclose event" do
        driver.close
        expect(@close).to eq false
      end

      it "does not trigger the onerror event" do
        driver.close
        expect(@error).to eq false
      end

      it "changes the state to :closing" do
        driver.close
        expect(driver.state).to eq :closing
      end
    end
  end

  describe "when masking is required" do
    before do
      options[:require_masking] = true
      driver.start
    end

    it "does not emit a message" do
      driver.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f].pack("C*")
      expect(@message).to eq ""
    end

    it "returns an error" do
      driver.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f].pack("C*")
      expect(@close).to eq [1003, "Received unmasked frame but masking is required"]
    end
  end

  describe "in the :closing state" do
    before do
      driver.start
      driver.close
    end

    describe :frame do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.frame("dropped")
      end

      it "returns false" do
        expect(driver.frame("wut")).to eq false
      end
    end

    describe :ping do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.ping
      end

      it "returns false" do
        expect(driver.ping).to eq false
      end
    end

    describe :pong do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.pong
      end

      it "returns false" do
        expect(driver.pong).to eq false
      end
    end

    describe :close do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.close
      end

      it "returns false" do
        expect(driver.close).to eq false
      end
    end

    describe "receiving a close frame" do
      before do
        driver.parse [0x88, 0x04, 0x03, 0xe9, 0x4f, 0x4b].pack("C*")
      end

      it "triggers the onclose event" do
        expect(@close).to eq [1001, "OK"]
      end

      it "changes the state to :closed" do
        expect(driver.state).to eq :closed
      end

      it "does not write another close frame" do
        expect(socket).not_to receive(:write)
        driver.parse [0x88, 0x04, 0x03, 0xe9, 0x4f, 0x4b].pack("C*")
      end
    end

    describe "receiving a close frame with a too-short payload" do
      before do
        driver.parse [0x88, 0x01, 0x03].pack("C*")
      end

      it "triggers the onclose event with a protocol error" do
        expect(@close).to eq [1002, ""]
      end

      it "changes the state to :closed" do
        expect(driver.state).to eq :closed
      end
    end

    describe "receiving a close frame with no code" do
      before do
        driver.parse [0x88, 0x00].pack("C*")
      end

      it "triggers the onclose event with code 1000" do
        expect(@close).to eq [1000, ""]
      end

      it "changes the state to :closed" do
        expect(driver.state).to eq :closed
      end
    end
  end

  describe "in the :closed state" do
    before do
      driver.start
      driver.close
      driver.parse [0x88, 0x02, 0x03, 0xea].pack("C*")
    end

    describe :frame do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.frame("dropped")
      end

      it "returns false" do
        expect(driver.frame("wut")).to eq false
      end
    end

    describe :ping do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.ping
      end

      it "returns false" do
        expect(driver.ping).to eq false
      end
    end

    describe :pong do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.pong
      end

      it "returns false" do
        expect(driver.pong).to eq false
      end
    end

    describe :close do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.close
      end

      it "returns false" do
        expect(driver.close).to eq false
      end

      it "leaves the state as :closed" do
        driver.close
        expect(driver.state).to eq :closed
      end
    end
  end
end
