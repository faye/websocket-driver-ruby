# encoding=utf-8

shared_examples_for "draft-75 protocol" do
  describe "in the :open state" do
    before { driver.start }

    describe :parse do
      it "parses text frames" do
        driver.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff].pack("C*")
        expect(@message).to eq "Hello"
      end

      it "parses multiple frames from the same packet" do
        driver.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff].pack("C*")
        expect(@message).to eq "HelloHello"
      end

      it "parses text frames beginning 0x00-0x7F" do
        driver.parse [0x66, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff].pack("C*")
        expect(@message).to eq "Hello"
      end

      it "ignores frames with a length header" do
        driver.parse [0x80, 0x02, 0x48, 0x65, 0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff].pack("C*")
        expect(@message).to eq "Hello"
      end

      it "parses multibyte text frames" do
        driver.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff].pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses frames received in several packets" do
        driver.parse [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65].pack("C*")
        driver.parse [0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff].pack("C*")
        expect(@message).to eq encode("Apple = ")
      end

      it "parses fragmented frames" do
        driver.parse [0x00, 0x48, 0x65, 0x6c].pack("C*")
        driver.parse [0x6c, 0x6f, 0xff].pack("C*")
        expect(@message).to eq "Hello"
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
          buffer = [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff].pack('C*')
          expect { driver.parse buffer }.to raise_error(RuntimeError, "an error")
        end

        it "parses text frames without dropping input" do
          driver.parse [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff, 0x00, 0x57].pack("C*") rescue nil
          driver.parse [0x6f, 0x72, 0x6c, 0x64, 0xff].pack("C*") rescue nil
          expect(@messages).to eq(["Hello", "World"])
        end
      end
    end

    describe :frame do
      it "formats the given string as a WebSocket frame" do
        driver.frame "Hello"
        expect(@bytes).to eq [0x00, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0xff]
      end

      it "encodes multibyte characters correctly" do
        message = encode("Apple = ")
        driver.frame message
        expect(@bytes).to eq [0x00, 0x41, 0x70, 0x70, 0x6c, 0x65, 0x20, 0x3d, 0x20, 0xef, 0xa3, 0xbf, 0xff]
      end

      it "returns true" do
        expect(driver.frame("lol")).to eq true
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

    describe :close do
      it "triggers the onclose event" do
        driver.close
        expect(@close).to eq true
      end

      it "returns true" do
        expect(driver.close).to eq true
      end

      it "changes the state to :closed" do
        driver.close
        expect(driver.state).to eq :closed
      end
    end
  end

  describe "in the :closed state" do
    before do
      driver.start
      driver.close
    end

    describe :close do
      it "does not write to the socket" do
        expect(socket).not_to receive(:write)
        driver.close
      end

      it "returns false" do
        expect(driver.close).to eq false
      end

      it "leaves the protocol in the :closed state" do
        driver.close
        expect(driver.state).to eq :closed
      end
    end
  end
end
