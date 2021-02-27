
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'lucasuite'
  spec.version       = '0.1.0'
  spec.license       = 'GPL'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 2.6.0'

  spec.summary       = %q{ERP apps}
  spec.description   = <<~DESC
   ERP apps
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca'
    spec.metadata['changelog_uri'] = 'https://github.com/chumaltd/luca/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir["LICENSE"]
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }

  spec.add_dependency 'lucabook'
  spec.add_dependency 'lucadeal'
  spec.add_dependency 'lucasalary'
  spec.add_dependency 'lucaterm'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
  spec.add_development_dependency 'simplecov', '>= 0.19'
end
