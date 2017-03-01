require "spec_helper"

describe WebSocket::Driver::Hybi do
  let(:parser_class)   { WebSocketNative::Parser }
  let(:unparser_class) { WebSocketNative::Unparser }

  def create_driver
    WebSocket::Driver::Hybi.new(socket, options)
  end

  it_should_behave_like "hybi driver"
end
