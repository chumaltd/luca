
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca_deal/version'

Gem::Specification.new do |spec|
  spec.name          = 'lucadeal'
  spec.version       = LucaDeal::VERSION
  spec.license       = 'GPL'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 3.0.0'

  spec.summary       = %q{Deal with contracts}
  spec.description   =<<~DESC
   Deal with contracts
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca/tree/master/lucadeal'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucadeal'
    spec.metadata['changelog_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucadeal/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir["CHANGELOG.md", "README.md", "LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = 'exe'
  spec.executables   = ['luca-deal']
  spec.require_paths = ['lib']

  spec.add_dependency 'lucarecord', '>= 0.6.0'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
