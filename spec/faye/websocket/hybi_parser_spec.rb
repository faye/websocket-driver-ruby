# encoding=utf-8

require "spec_helper"

describe Faye::WebSocket::HybiParser do
  include EncodingHelper

  before do
    @web_socket = mock Faye::WebSocket
    @web_socket.stub(:write) { |message| @bytes = bytes(message) }

    @parser = Faye::WebSocket::HybiParser.new(@web_socket)
    @message = ""
    @parser.onmessage { |message| @message += message }
    @parser.onclose { |code, reason| @close = [code, reason] }
  end

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
      parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      @message.should == "Hello"
    end

    it "parses multiple frames from the same packet" do
      parse [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      @message.should == "HelloHello"
    end

    it "parses empty text frames" do
      parse [0x81, 0x00]
      @message.should == ""
    end

    it "parses fragmented text frames" do
      parse [0x01, 0x03, 0x48, 0x65, 0x6c]
      parse [0x80, 0x02, 0x6c, 0x6f]
      @message.should == "Hello"
    end

    it "parses masked text frames" do
      parse [0x81, 0x85] + mask + mask_message(0x48, 0x65, 0x6c, 0x6c, 0x6f)
      @message.should == "Hello"
    end

    it "parses masked empty text frames" do
      parse [0x81, 0x80] + mask + mask_message()
      @message.should == ""
    end

    it "parses masked fragmented text frames" do
      parse [0x01, 0x81] + mask + mask_message(0x48)
      parse [0x80, 0x84] + mask + mask_message(0x65, 0x6c, 0x6c, 0x6f)
      @message.should == "Hello"
    end

    it "closes the socket if the frame has an unrecognized opcode" do
      parse [0x83, 0x00]
      @close.should == [1002, nil]
    end

    it "closes the socket if a close frame is received" do
      parse [0x88, 0x07, 0x03, 0xe8, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
      @close.should == [1000, "Hello"]
    end

    it "parses unmasked multibyte text frames" do
      parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
      @message.should == encode("Apple = ")
    end

    it "parses frames received in several packets" do
      parse [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c]
      parse [0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
      @message.should == encode("Apple = ")
    end

    it "parses fragmented multibyte text frames" do
      parse [0x01, 0x0a, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3]
      parse [0x80, 0x01, 0xbf]
      @message.should == encode("Apple = ")
    end

    it "parses masked multibyte text frames" do
      parse [0x81, 0x8b] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf)
      @message.should == encode("Apple = ")
    end

    it "parses masked fragmented multibyte text frames" do
      parse [0x01, 0x8a] + mask + mask_message(0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3)
      parse [0x80, 0x81] + mask + mask_message(0xbf)
      @message.should == encode("Apple = ")
    end

    it "parses unmasked medium-length text frames" do
      parse [0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40
      @message.should == "Hello" * 40
    end

    it "parses masked medium-length text frames" do
      parse [0x81, 0xfe, 0x00, 0xc8] + mask + mask_message(*([0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40))
      @message.should == "Hello" * 40
    end

    it "replies to pings with a pong" do
      parse [0x89, 0x04, 0x4f, 0x48, 0x41, 0x49]
      @bytes.should == [0x8a, 0x04, 0x4f, 0x48, 0x41, 0x49]
    end
  end

  describe :frame do
    it "returns the given string formatted as a WebSocket frame" do
      @parser.frame "Hello"
      @bytes.should == [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
    end

    it "encodes multibyte characters correctly" do
      message = encode "Apple = "
      @parser.frame message
      @bytes.should == [0x81, 0x0b, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf]
    end

    it "encodes medium-length strings using extra length bytes" do
      message = "Hello" * 40
      @parser.frame message
      @bytes.should == [0x81, 0x7e, 0x00, 0xc8] + [0x48, 0x65, 0x6c, 0x6c, 0x6f] * 40
    end

    it "encodes close frames with an error code" do
      @parser.frame "Hello", :close, 1002
      @bytes.should == [0x88, 0x07, 0x03, 0xea, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
    end

    it "encodes pong frames" do
      @parser.frame '', :pong
      @bytes.should == [0x8a, 0x00]
    end
  end

  describe :utf8 do
    it "detects valid UTF-8" do
      Faye::WebSocket.valid_utf8?( [72, 101, 108, 108, 111, 45, 194, 181, 64, 195, 159, 195, 182, 195, 164, 195, 188, 195, 160, 195, 161, 45, 85, 84, 70, 45, 56, 33, 33] ).should be_true
    end

    it "detects invalid UTF-8" do
      Faye::WebSocket.valid_utf8?( [206, 186, 225, 189, 185, 207, 131, 206, 188, 206, 181, 237, 160, 128, 101, 100, 105, 116, 101, 100] ).should be_false
    end
  end
end
