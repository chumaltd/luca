
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca_salary/version'

Gem::Specification.new do |spec|
  spec.name          = 'lucasalary'
  spec.version       = LucaSalary::VERSION
  spec.license       = 'GPL-3.0-or-later'
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.required_ruby_version = '>= 3.0.0'

  spec.summary       = %q{Salary calculation framework}
  spec.description   = <<~DESC
   Salary calculation framework
  DESC
  spec.homepage      = 'https://github.com/chumaltd/luca/tree/master/lucasalary'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucasalary'
    spec.metadata['changelog_uri'] = 'https://github.com/chumaltd/luca/tree/master/lucasalary/CHANGELOG.md'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files         = Dir["CHANGELOG.md", "README.md", "LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = 'exe'
  spec.executables   = ['luca-salary']
  spec.require_paths = ['lib']

  spec.add_dependency 'lucarecord', '>= 0.7.0'

  spec.add_development_dependency 'bundler', '>= 1.17'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '>= 12.3.3'
end
