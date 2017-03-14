require 'rubygems'
require 'bundler/setup'
require 'benchmark/ips'
require 'websocket/driver'

require File.expand_path('../generator', __FILE__)

socket = Object.new
driver = WebSocket::Driver::Hybi.new(socket, :native => true)

driver.on :message do |message|
  s = message.data
  p [:received, [s.bytesize, s.encoding], s]
  puts
end

message_count  = 5
message_size   = 2 ** 8
fragment_count = 1
chop_size      = 64

create_chunks(message_count, message_size, fragment_count, chop_size).each do |chunk|
  # p [:push, chunk.bytesize, chunk.bytes[0..15]]
  driver.parse(chunk)
end
