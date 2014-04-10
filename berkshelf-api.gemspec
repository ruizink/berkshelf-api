# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'berkshelf/api/version'

Gem::Specification.new do |spec|
  spec.name          = "berkshelf-api"
  spec.version       = Berkshelf::API::VERSION
  spec.authors       = ["Jamie Winsor", "Andrew Garson"]
  spec.email         = ["jamie@vialstudios.com", "agarson@riotgames"]
  spec.description   = %q{Berkshelf dependency API server}
  spec.summary       = %q{A server which indexes cookbooks from various sources and hosts it over a REST API}
  spec.homepage      = "https://github.com/berkshelf/berkshelf-api"
  spec.license       = "Apache 2.0"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(spec|features)/})
  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 1.9.3"

  spec.add_dependency 'ridley',         '~> 3.0'
  spec.add_dependency 'celluloid',      '~> 0.16.0.pre'
  spec.add_dependency 'reel',           '>= 0.4.0'
  spec.add_dependency 'http',           '~> 0.5.0' # explicitly lock because reel's is too lax
  spec.add_dependency 'grape',          '~> 0.6'
  spec.add_dependency 'grape-msgpack',  '~> 0.1'
  spec.add_dependency 'hashie',         '>= 2.0.4'
  spec.add_dependency 'faraday',        '~> 0.9.0'
  spec.add_dependency 'retryable',      '~> 1.3.3'
  spec.add_dependency 'archive',        '= 0.0.6'
  spec.add_dependency 'buff-config',    '~> 0.1'
  spec.add_dependency 'octokit',        '~> 2.6'
  spec.add_dependency 'semverse',       '~> 1.0'

  spec.add_development_dependency 'bundler',   '~> 1.3'
  spec.add_development_dependency 'thor',      '~> 0.18'
  spec.add_development_dependency 'chef-zero', '~> 1.5'
  spec.add_development_dependency "octokit",   '~> 2.6'
end
