
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca_term/version'

Gem::Specification.new do |spec|
  spec.name          = 'lucaterm'
  spec.version       = LucaTerm::VERSION
  spec.license       = 'GPL'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 2.6.0'

  spec.summary       = %q{Terminal frontend for Luca Suite}
  spec.description   =<<~DESC
   Terminal frontend for Luca Suite
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca/tree/master/lucaterm'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucaterm'
    spec.metadata['changelog_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucaterm/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir["CHANGELOG.md", "README.md", "LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = 'exe'
  spec.executables   = ['luca']
  spec.require_paths = ['lib']

  spec.add_dependency 'curses'
  spec.add_dependency 'mb_string'
  spec.add_dependency 'lucabook'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
