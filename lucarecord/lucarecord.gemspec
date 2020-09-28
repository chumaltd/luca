
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'luca_record/version'

Gem::Specification.new do |spec|
  spec.name          = 'lucarecord'
  spec.version       = LucaRecord::VERSION
  spec.authors       = ['Chuma Takahiro']
  spec.email         = ['co.chuma@gmail.com']

  spec.summary       = %q{ERP File operation framework}
  spec.description   = <<~DESC
    ERP File operation framework
  DESC
  spec.homepage      = "https://github.com/chumaltd/luca/lucarecord"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

    spec.metadata["homepage_uri"] = spec.homepage
    spec.metadata["source_code_uri"] = "https://github.com/chumaltd/luca/lucarecord"
    spec.metadata["changelog_uri"] = "https://github.com/chumaltd/luca/lucarecord/CHANGELOG.md"
  else
    raise "RubyGems 2.0 or newer is required to protect against " \
      "public gem pushes."
  end

  spec.files         = Dir["CHANGELOG.md", "LICENSE", "exe/**/*", "lib/**/{*,.[a-z]*}"]
  spec.bindir        = "exe"
  spec.executables   = []
  spec.require_paths = ["lib"]

  spec.add_dependency 'mail'

  spec.add_development_dependency 'bundler', '~> 1.17'
  spec.add_development_dependency 'rake', '~> 12.3.3'
  spec.add_development_dependency 'minitest', '~> 5.0'
end
