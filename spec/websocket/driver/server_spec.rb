# encoding=utf-8

require "spec_helper"

describe WebSocket::Driver::Hybi do
  let :options do
    {
      :masking => true,
      :require_masking => true
    }
  end
  
  def receive_data(driver, buffer)
    listener = driver.add_listener(:message) do |event|
      return event.data
    end
    
    driver.parse(buffer)
  ensure
    driver.remove_listener(:message, listener)
  end
  
  def test_return(driver, buffer)
    receive_data(driver, buffer) do |data|
      return data
    end
  end
  
  it "should handle exception in message callback" do
    client_buffer = StringIO.new
    server_buffer = StringIO.new
    
    server = WebSocket::Driver::Server.new(server_buffer, options)
    
    def client_buffer.url
      "http://localhost/"
    end
    
    # Start the client and generate a request for the server in the client buffer:
    client = WebSocket::Driver::Client.new(client_buffer, options)
    client.start
    
    # Start the server and parse the incoming client request, generate an upgrade response:
    server.start # Write upgrade response..
    server.parse(client_buffer.string)
    client_buffer.truncate(0); client_buffer.seek(0)
    
    # Parse the upgrade response, headers, etc.
    client.parse(server_buffer.string)
    server_buffer.truncate(0); server_buffer.seek(0)
    
    # Send the message to the server:
    3.times do
      client.text("Hello World")
      
      response = receive_data(server, client_buffer.string)
      client_buffer.truncate(0); client_buffer.seek(0)
      
      expect(response).to be == "Hello World"
    end
  end
end
