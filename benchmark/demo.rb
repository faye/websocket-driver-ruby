require 'rubygems'
require 'bundler/setup'
require 'benchmark/ips'

require 'websocket_parser'

require File.expand_path('../generator', __FILE__)

driver = WebSocketParser.new

message_count  = 5
message_size   = 2 ** 8
fragment_count = 1
chop_size      = 64

create_chunks(message_count, message_size, fragment_count, chop_size).each do |chunk|
  # p [:push, chunk.bytesize, chunk.bytes[0..15]]
  driver.parse(chunk)
end
