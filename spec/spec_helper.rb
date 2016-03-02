require 'rubygems'
require 'bundler/setup'

require File.expand_path('../../lib/websocket/driver', __FILE__)
require File.expand_path('../websocket/driver/draft75_examples', __FILE__)

module EncodingHelper
  def encode(message)
    message.respond_to?(:force_encoding) ?
        message.dup.force_encoding("UTF-8") :
        message
  end

  def bytes(string)
    string.bytes.to_a
  end
end
