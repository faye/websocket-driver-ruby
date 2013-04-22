Gem::Specification.new do |s|
  s.name              = "websocket-protocol"
  s.version           = "0.0.0"
  s.summary           = "Standards-compliant WebSocket protocol handlers"
  s.author            = "James Coglan"
  s.email             = "jcoglan@gmail.com"
  s.homepage          = "http://github.com/faye/websocket-protocol-ruby"

  s.extra_rdoc_files  = %w[README.rdoc]
  s.rdoc_options      = %w[--main README.rdoc]
  s.require_paths     = %w[lib]

  files = %w[README.rdoc CHANGELOG.txt] +
          Dir.glob("ext/**/*.{c,java,rb}") +
          Dir.glob("lib/**/*.rb")

  if RUBY_PLATFORM =~ /java/
    s.platform = "java"
    files << "lib/websocket_mask.jar"
  else
    s.extensions << "ext/websocket_mask/extconf.rb"
  end

  s.files = files

  s.add_development_dependency "rake-compiler"
  s.add_development_dependency "rspec"
end

