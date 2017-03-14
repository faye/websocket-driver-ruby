require 'rubygems'
require 'bundler/setup'
require 'websocket/driver'
require 'memory_profiler'

dir = File.expand_path('../../ext/test/autobahn', __FILE__)
tests = []

Dir.entries(dir).each do |file|
  next if %w[. ..].include?(file)
  tests << File.read(File.join(dir, file))
end

native = (ARGV.first == 'native')
socket = Object.new

report = MemoryProfiler.report do
  tests.each do |test|
    driver = WebSocket::Driver::Hybi.new(socket, :native => native)
    driver.parse(test)
  end
end

report.pretty_print
