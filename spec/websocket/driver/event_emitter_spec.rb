require 'spec_helper'

describe WebSocket::Driver::EventEmitter do
  Target = Class.new { include WebSocket::Driver::EventEmitter }

  let(:target) { Target.new }
  let(:events) { [] }

  it "adds listeners using a string and emits using a string" do
    target.on("event", &events.method(:<<))
    target.emit("event", 1)
    expect(events).to eq [1]
  end

  it "adds listeners using a string and emits using a symbol" do
    target.on("event", &events.method(:<<))
    target.emit(:event, 2)
    expect(events).to eq [2]
  end

  it "adds listeners using a symbol and emits using a string" do
    target.on(:event, &events.method(:<<))
    target.emit("event", 3)
    expect(events).to eq [3]
  end

  it "adds listeners using a symbol and emits using a symbol" do
    target.on(:event, &events.method(:<<))
    target.emit(:event, 4)
    expect(events).to eq [4]
  end

  it "allows mixed use of a string then a symbol" do
    target.on("event") { |e| events << [:string, e] }
    target.on(:event) { |e| events << [:symbol, e] }
    target.emit("event", 5)
    target.emit(:event, 6)
    expect(events).to eq [[:string, 5], [:symbol, 5], [:string, 6], [:symbol, 6]]
  end

  it "allows mixed use of a symbol then a string" do
    target.on(:event) { |e| events << [:symbol, e] }
    target.on("event") { |e| events << [:string, e] }
    target.emit(:event, 7)
    target.emit("event", 8)
    expect(events).to eq [[:symbol, 7], [:string, 7], [:symbol, 8], [:string, 8]]
  end
end
