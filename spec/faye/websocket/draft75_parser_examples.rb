# encoding=utf-8

require "spec_helper"

shared_examples_for "draft-75 parser" do
  describe "in the :open state" do
    before { parser.start }

    describe :parse do
      it "parses text frames" do
        parser.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "parses multiple frames from the same packet" do
        parser.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "HelloHello"
      end

      it "parses text frames beginning 0x00-0x7F" do
        parser.parse [0x66, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "ignores frames with a length header" do
        parser.parse [0x80, 0x02, 0x48, 0x65, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end

      it "parses multibyte text frames" do
        parser.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
        @message.should == encode("Apple = ")
      end

      it "parses frames received in several packets" do
        parser.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65]
        parser.parse [0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
        @message.should == encode("Apple = ")
      end

      it "parses fragmented frames" do
        parser.parse [0x00, 0x48, 0x65, 0x6c]
        parser.parse [0x6c, 0x6f, 0xff]
        @message.should == "Hello"
      end
    end

    describe :frame do
      it "formats the given string as a WebSocket frame" do
        parser.frame "Hello"
        @bytes.should == [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
      end

      it "encodes multibyte characters correctly" do
        message = encode "Apple = "
        parser.frame message
        @bytes.should == [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
      end

      it "returns true" do
        parser.frame("lol").should == true
      end
    end

    describe :ping do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        parser.ping
      end

      it "returns false" do
        parser.ping.should == false
      end
    end

    describe :close do
      it "triggers the onclose event" do
        parser.close
        @close.should == true
      end

      it "returns true" do
        parser.close.should == true
      end

      it "changes the state to :closed" do
        parser.close
        parser.state.should == :closed
      end
    end
  end

  describe "in the :closed state" do
    before do
      parser.start
      parser.close
    end

    describe :close do
      it "does not write to the socket" do
        socket.should_not_receive(:write)
        parser.close
      end

      it "returns false" do
        parser.close.should == false
      end

      it "leaves the parser in the :closed state" do
        parser.close
        parser.state.should == :closed
      end
    end
  end
end

