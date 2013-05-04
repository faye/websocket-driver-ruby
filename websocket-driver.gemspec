Gem::Specification.new do |s|
  s.name              = 'websocket-driver'
  s.version           = '0.1.0'
  s.summary           = 'WebSocket protocol handler with pluggable I/O'
  s.author            = 'James Coglan'
  s.email             = 'jcoglan@gmail.com'
  s.homepage          = 'http://github.com/faye/websocket-driver-ruby'

  s.extra_rdoc_files  = %w[README.md]
  s.rdoc_options      = %w[--main README.md --markup markdown]
  s.require_paths     = %w[lib]

  files = %w[README.md CHANGELOG.md] +
          Dir.glob('ext/**/*.{c,java,rb}') +
          Dir.glob('lib/**/*.rb')

  if RUBY_PLATFORM =~ /java/
    s.platform = 'java'
    files << 'lib/websocket_mask.jar'
  else
    s.extensions << 'ext/websocket_mask/extconf.rb'
  end

  s.files = files

  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'rspec'
end

