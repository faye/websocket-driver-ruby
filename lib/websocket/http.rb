module WebSocket
  module HTTP

    root = File.expand_path('../http', __FILE__)

    autoload :Headers,  root + '/headers'
    autoload :Request,  root + '/request'
    autoload :Response, root + '/response'

  end
end

