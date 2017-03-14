require 'rubygems'
require 'bundler/setup'
require 'benchmark/ips'
require 'websocket/driver'

require File.expand_path('../generator', __FILE__)

socket = Object.new
pure   = WebSocket::Driver::Hybi.new(socket)
native = WebSocket::Driver::Hybi.new(socket, :native => true)

message_count  = 100
message_size   = 2 ** 7
fragment_count = 1
chop_size      = 128

chunks = create_chunks(message_count, message_size, fragment_count, chop_size)

Benchmark.ips do |bm|
  bm.report 'Ruby parser' do
    chunks.each { |chunk| pure.parse chunk }
  end

  bm.report 'Native parser' do
    chunks.each { |chunk| native.parse chunk }
  end
end
