Gem::Specification.new do |s|
  s.name              = "faye-websocket-parser"
  s.version           = "0.1.0"
  s.summary           = "Standards-compliant WebSocket parsers"
  s.author            = "James Coglan"
  s.email             = "jcoglan@gmail.com"
  s.homepage          = "http://github.com/faye/faye-websocket-parser-ruby"

  s.extra_rdoc_files  = %w[README.rdoc]
  s.rdoc_options      = %w[--main README.rdoc]
  s.require_paths     = %w[lib]

  files = %w[README.rdoc CHANGELOG.txt] +
          Dir.glob("ext/**/*.{c,java,rb}") +
          Dir.glob("lib/**/*.rb") +
          Dir.glob("spec/**/*")

  if RUBY_PLATFORM =~ /java/
    s.platform = "java"
    files << "lib/faye_websocket_mask.jar"
  else
    s.extensions << "ext/faye_websocket_mask/extconf.rb"
  end

  s.files = files

  s.add_development_dependency "rake-compiler"
  s.add_development_dependency "rspec"
end

