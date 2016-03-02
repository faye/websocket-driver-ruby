# encoding=utf-8

require "spec_helper"

describe WebSocket::Driver::Draft75 do
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
    socket = double(WebSocket)
    allow(socket).to receive(:env).and_return(env)
    allow(socket).to receive(:url).and_return("ws://www.example.com/socket")
    allow(socket).to receive(:write) { |message| @bytes = bytes(message) }
    socket
  end

  let :driver do
    driver = WebSocket::Driver::Draft75.new(socket)
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
    it "starts in the :connecting state" do
      expect(driver.state).to eq :connecting
    end

    describe :start do
      it "writes the handshake response to the socket" do
        expect(socket).to receive(:write).with(
            "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "WebSocket-Origin: http://www.example.com\r\n" +
            "WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
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
        expect(driver.version).to eq "hixie-75"
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
            "HTTP/1.1 101 Web Socket Protocol Handshake\r\n" +
            "Upgrade: WebSocket\r\n" +
            "Connection: Upgrade\r\n" +
            "WebSocket-Origin: http://www.example.com\r\n" +
            "WebSocket-Location: ws://www.example.com/socket\r\n" +
            "\r\n")
        expect(socket).to receive(:write).with(WebSocket::Driver.encode String.new("\x00Hi\xFF"), :binary)

        driver.frame("Hi")
        driver.start

        expect(@bytes).to eq [0x00, 72, 105, 0xFF]
      end
    end
  end

  it_should_behave_like "draft-75 protocol"
end
