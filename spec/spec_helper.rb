require 'rubygems'
require 'bundler/setup'

require File.expand_path('../../lib/websocket/protocol', __FILE__)
require File.expand_path('../websocket/protocol/draft75_examples', __FILE__)

module EncodingHelper
  def encode(message)
    message.respond_to?(:force_encoding) ?
        message.force_encoding("UTF-8") :
        message
  end

  def bytes(string)
    string.bytes.to_a
  end
end

