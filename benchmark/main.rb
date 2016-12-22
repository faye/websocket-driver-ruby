require 'rubygems'
require 'bundler/setup'
require 'benchmark/ips'
require 'websocket/driver'

require 'websocket_parser'

require File.expand_path('../generator', __FILE__)

socket = Object.new
driver = WebSocket::Driver::Hybi.new(socket)
parser = WebSocketParser.new

message_count  = 100
message_size   = 2 ** 7
fragment_count = 1
chop_size      = 128

chunks = create_chunks(message_count, message_size, fragment_count, chop_size)

Benchmark.ips do |bm|
  bm.report 'Hybi driver' do
    chunks.each { |chunk| driver.parse chunk }
  end

  bm.report 'C parser' do
    chunks.each { |chunk| parser.parse chunk }
  end
end
