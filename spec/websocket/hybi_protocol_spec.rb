# encoding=utf-8

require "spec_helper"

describe WebSocket::HybiProtocol do
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
    {:masking => false}
  end

  let :socket do
    socket = mock(WebSocket)
    socket.stub(:env).and_return(env)
    socket.stub(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :protocol do
    protocol = WebSocket::HybiProtocol.new(socket, options)
    protocol.onopen    { |e| @open = true }
    protocol.onmessage { |e| @message += e.data }
    protocol.onclose   { |e| @close = [e.code, e.reason] }
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
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        protocol.start
      end

      it "returns true" do
        protocol.start.should == true
      end

      describe "with subprotocols" do
        before do
          env["HTTP_SEC_WEBSOCKET_PROTOCOL"] = "foo, bar, xmpp"
          options[:protocols] = ["xmpp"]
        end

        it "writes the handshake with Sec-WebSocket-Protocol" do
          socket.should_receive(:write).with(
              "HTTP/1.1 101 Switching Protocols\r\n" +
              "Upgrade: websocket\r\n" +
              "Connection: Upgrade\r\n" +
              "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
              "Sec-WebSocket-Protocol: xmpp\r\n" +
              "\r\n")
          protocol.start
        end
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
        protocol.version.should == "hybi-13"
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
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        socket.should_receive(:write).with(WebSocket::Protocol.encode [0x81, 2, 72, 105])

        protocol.frame("Hi")
        protocol.start

        @bytes.should == [0x81, 2, 72, 105]
      end
    end

    describe :ping do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.ping
      end

      it "returns true" do
        protocol.ping.should == true
      end

      it "queues the ping until the handshake has been sent" do
        socket.should_receive(:write).with(
            "HTTP/1.1 101 Switching Protocols\r\n" +
            "Upgrade: websocket\r\n" +
            "Connection: Upgrade\r\n" +
            "Sec-WebSocket-Accept: JdiiuafpBKRqD7eol0y4vJDTsTs=\r\n" +
            "\r\n")
        socket.should_receive(:write).with(WebSocket::Protocol.encode [137, 0])

        protocol.ping
        protocol.start

        @bytes.should == [0x89, 0]
      end
    end

    describe :close do
      it "does not write anything to the socket" do
        socket.should_not_receive(:write)
        protocol.close
      end

      it "returns true" do
        protocol.close.should == true
      end

      it "triggers the onclose event" do
        protocol.close
        @close.should == [1000, ""]
      end

      it "changes the state to :closed" do
        protocol.close
        protocol.state.should == :closed
      end
    end
  end

  describe "in the :open state" do
    before { protocol.start }

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
        protocol.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        @message.should == "Hello"
      end

      it "parses multiple frames from the same packet" do
        protocol.parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        @message.should == "HelloHello"
      end

      it "parses empty text frames" do
        protocol.parse [0x81, 0x00]
        @message.should == ""
      end

      it "parses fragmented text frames" do
        protocol.parse [0x01, 0x03, 0x48, 0x65, 0x6c]
        protocol.parse [0x80, 0x02, 0x6c, 0x6f]
        @message.should == "Hello"
      end

      it "parses masked text frames" do
        protocol.parse [0x81, 0x85] + mask + mask_message(0x48, 0x65, 0x6c, 0x6c, 0x6f)
        @message.should == "Hello"
      end

      it "parses masked empty text frames" do
        protocol.parse [0x81, 0x80] + mask + mask_message()
        @message.should == ""
      end

      it "parses masked fragmented text frames" do
        protocol.parse [0x01, 0x81] + mask + mask_message(0x48)
        protocol.parse [0x80, 0x84] + mask + mask_message(0x65, 0x6c, 0x6c, 0x6f)
        @message.should == "Hello"
      end

      it "closes the socket if the frame has an unrecognized opcode" do
        protocol.parse [0x83, 0x00]
        @bytes.should == [0x88, 0x02, 0x03, 0xea]
        @close.should == [1002, nil]
        protocol.state.should == :closed
      end

      it "closes the socket if a close frame is received" do
        protocol.parse [0x88, 0x07, 0x03, 0xe8, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        @bytes.should == [0x88, 0x07, 0x03, 0xe8, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        @close.should == [1000, "Hello"]
        protocol.state.should == :closed
      end

      it "parses unmasked multibyte text frames" do
        protocol.parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
        @message.should == encode("Apple = ")
      end

      it "parses frames received in several packets" do
        protocol.parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c]
        protocol.parse [0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
        @message.should == encode("Apple = ")
      end

      it "parses fragmented multibyte text frames" do
        protocol.parse [0x01, 0x0a, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3]
        protocol.parse [0x80, 0x01, 0xbf]
        @message.should == encode("Apple = ")
      end

      it "parses masked multibyte text frames" do
        protocol.parse [0x81, 0x8b] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf)
        @message.should == encode("Apple = ")
      end

      it "parses masked fragmented multibyte text frames" do
        protocol.parse [0x01, 0x8a] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3)
        protocol.parse [0x80, 0x81] + mask + mask_message(0xbf)
        @message.should == encode("Apple = ")
      end

      it "parses unmasked medium-length text frames" do
        protocol.parse [0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40
        @message.should == "Hello" * 40
      end

      it "parses masked medium-length text frames" do
        protocol.parse [0x81, 0xfe, 0x00, 0xc8] + mask + mask_message(*([0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40))
        @message.should == "Hello" * 40
      end

      it "replies to pings with a pong" do
        protocol.parse [0x89, 0x04, 0x4f, 0x48, 0x41, 0x49]
        @bytes.should == [0x8a, 0x04, 0x4f, 0x48, 0x41, 0x49]
      end
    end

    describe :frame do
      it "formats the given string as a WebSocket frame" do
        protocol.frame "Hello"
        @bytes.should == [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      end

      it "formats a byte array as a binary WebSocket frame" do
        protocol.frame [0x48, 0x65, 0x6c]
        @bytes.should == [0x82, 0x03, 0x48, 0x65, 0x6c]
      end

      it "encodes multibyte characters correctly" do
        message = encode "Apple = "
        protocol.frame message
        @bytes.should == [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
      end

      it "encodes medium-length strings using extra length bytes" do
        message = "Hello" * 40
        protocol.frame message
        @bytes.should == [0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40
      end

      it "encodes close frames with an error code" do
        protocol.frame "Hello", :close, 1002
        @bytes.should == [0x88, 0x07, 0x03, 0xea, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      end

      it "encodes pong frames" do
        protocol.frame "", :pong
        @bytes.should == [0x8a, 0x00]
      end
    end

    describe :ping do
      it "writes a ping frame to the socket" do
        protocol.ping("mic check")
        @bytes.should == [0x89, 0x09, 0x6d, 0x69, 0x63, 0x20, 0x63, 0x68, 0x65, 0x63, 0x6b]
      end

      it "returns true" do
        protocol.ping.should == true
      end

      it "runs the given callback on matching pong" do
        protocol.ping("Hi") { @reply = true }
        protocol.parse [0x8a, 0x02, 72, 105]
        @reply.should == true
      end

      it "does not run the callback on non-matching pong" do
        protocol.ping("Hi") { @reply = true }
        protocol.parse [0x8a, 0x03, 119, 97, 116]
        @reply.should == nil
      end
    end

    describe :close do
      it "writes a close frame to the socket" do
        protocol.close("<%= reasons %>", 1003)
        @bytes.should == [0x88, 0x10, 0x03, 0xeb, 0x3c, 0x25, 0x3d, 0x20, 0x72, 0x65, 0x61, 0x73, 0x6f, 0x6e, 0x73, 0x20, 0x25, 0x3e]
      end

      it "returns true" do
        protocol.close.should == true
      end

      it "does not trigger the onclose event" do
        protocol.close
        @close.should == false
      end

      it "changes the state to :closing" do
        protocol.close
        protocol.state.should == :closing
      end
    end
  end

  describe "in the :closing state" do
    before do
      protocol.start
      protocol.close
    end

    describe :frame do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.frame("dropped")
      end

      it "returns false" do
        protocol.frame("wut").should == false
      end
    end

    describe :ping do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.ping
      end

      it "returns false" do
        protocol.ping.should == false
      end
    end

    describe :close do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.close
      end

      it "returns false" do
        protocol.close.should == false
      end
    end

    describe "receiving a close frame" do
      before do
        protocol.parse [0x88, 0x04, 0x03, 0xe9, 0x4f, 0x4b]
      end

      it "triggers the onclose event" do
        @close.should == [1001, "OK"]
      end

      it "changes the state to :closed" do
        protocol.state.should == :closed
      end
    end
  end

  describe "in the :closed state" do
    before do
      protocol.start
      protocol.close
      protocol.parse [0x88, 0x02, 0x03, 0xea]
    end

    describe :frame do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.frame("dropped")
      end

      it "returns false" do
        protocol.frame("wut").should == false
      end
    end

    describe :ping do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.ping
      end

      it "returns false" do
        protocol.ping.should == false
      end
    end

    describe :close do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.close
      end

      it "returns false" do
        protocol.close.should == false
      end

      it "leaves the state as :closed" do
        protocol.close
        protocol.state.should == :closed
      end
    end
  end

  describe :utf8 do
    it "detects valid UTF-8" do
      WebSocket::Protocol.valid_utf8?( [72, 101, 108, 108, 111, 45, 194, 181, 64, 195, 159, 195, 182, 195, 164, 195, 188, 195, 160, 195, 161, 45, 85, 84, 70, 45, 56, 33, 33] ).should == true
    end

    it "detects invalid UTF-8" do
      WebSocket::Protocol.valid_utf8?( [206, 186, 225, 189, 185, 207, 131, 206, 188, 206, 181, 237, 160, 128, 101, 100, 105, 116, 101, 100] ).should == false
    end
  end
end

