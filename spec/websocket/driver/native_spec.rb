describe WebSocket::Driver::Native do
  next if RUBY_PLATFORM =~ /java/

  def create_driver
    WebSocket::Driver::Native.new(socket, options)
  end

  it_should_behave_like "hybi driver"
end
