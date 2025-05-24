Gem::Specification.new do |s|
  s.name     = 'websocket-driver'
  s.version  = '0.8.0'
  s.summary  = 'WebSocket protocol handler with pluggable I/O'
  s.author   = 'James Coglan'
  s.email    = 'jcoglan@gmail.com'
  s.homepage = 'https://github.com/faye/websocket-driver-ruby'
  s.license  = 'Apache-2.0'

  s.metadata['changelog_uri'] = s.homepage + '/blob/main/CHANGELOG.md'

  s.extra_rdoc_files = %w[README.md]
  s.rdoc_options     = %w[--main README.md --markup markdown]
  s.require_paths    = %w[lib]

  files = %w[CHANGELOG.md LICENSE.md README.md] +
          Dir.glob('ext/**/*.{c,java,rb}') +
          Dir.glob('lib/**/*.rb')

  if RUBY_PLATFORM =~ /java/
    s.platform = 'java'
    files << 'lib/websocket_mask.jar'
  else
    s.extensions << 'ext/websocket-driver/extconf.rb'
  end

  s.files = files

  s.add_dependency 'base64'
  s.add_dependency 'websocket-extensions', '>= 0.1.0'

  s.add_development_dependency 'eventmachine'
  s.add_development_dependency 'permessage_deflate'
  s.add_development_dependency 'rake-compiler'
  s.add_development_dependency 'rspec'

  if RUBY_VERSION < '2.0.0'
    s.add_development_dependency 'rake', '< 12.3.0'
  end
end
