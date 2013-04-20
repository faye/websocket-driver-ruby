# encoding=utf-8

require "spec_helper"

shared_examples_for "draft-75 protocol" do
  describe "in the :open state" do
    before { protocol.start }

    describe :parse do
      it "parses text frames" do
        protocol.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "parses multiple frames from the same packet" do
        protocol.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "HelloHello"
      end

      it "parses text frames beginning 0x00-0x7F" do
        protocol.parse [0x66, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "ignores frames with a length header" do
        protocol.parse [0x80, 0x02, 0x48, 0x65, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "parses multibyte text frames" do
        protocol.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
        @message.should == encode("Apple = ")
      end

      it "parses frames received in several packets" do
        protocol.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65]
        protocol.parse [0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
        @message.should == encode("Apple = ")
      end

      it "parses fragmented frames" do
        protocol.parse [0x00, 0x48, 0x65, 0x6c]
        protocol.parse [0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end
    end

    describe :frame do
      it "formats the given string as a WebSocket frame" do
        protocol.frame "Hello"
        @bytes.should == [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
      end

      it "encodes multibyte characters correctly" do
        message = encode "Apple = "
        protocol.frame message
        @bytes.should == [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
      end

      it "returns true" do
        protocol.frame("lol").should == true
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
      it "triggers the onclose event" do
        protocol.close
        @close.should == true
      end

      it "returns true" do
        protocol.close.should == true
      end

      it "changes the state to :closed" do
        protocol.close
        protocol.state.should == :closed
      end
    end
  end

  describe "in the :closed state" do
    before do
      protocol.start
      protocol.close
    end

    describe :close do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        protocol.close
      end

      it "returns false" do
        protocol.close.should == false
      end

      it "leaves the protocol in the :closed state" do
        protocol.close
        protocol.state.should == :closed
      end
    end
  end
end

