begin
  extension_root = File.expand_path('../../ext', __FILE__)
  require extension_root + '/websocket_mask/websocket_mask.so'
rescue LoadError
  # @note rake-compiler builds websocket_mask.bundle in /lib on OSX
  require 'websocket_mask.so'
end
