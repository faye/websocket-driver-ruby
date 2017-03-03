require "spec_helper"

describe WebSocket::Driver::Hybi do
  def create_driver
    WebSocket::Driver::Hybi.new(socket, options.merge(:native => false))
  end

  it_should_behave_like "hybi driver"
end
