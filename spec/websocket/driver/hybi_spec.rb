require "spec_helper"

describe WebSocket::Driver::Hybi do
  let(:parser_class)   { nil }
  let(:unparser_class) { nil }

  def create_driver
    WebSocket::Driver::Hybi.new(socket, options)
  end

  it_should_behave_like "hybi driver"
end
