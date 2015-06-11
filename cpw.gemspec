# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cpw/version'

Gem::Specification.new do |spec|
  spec.name          = "CPW"
  spec.version       = CPW::VERSION
  spec.authors       = ["Juergen Fesslmeier"]
  spec.email         = ["jfesslmeier@gmail.com"]
  spec.summary       = %q{Content Processing Workflow}
  spec.description   = %q{Audio/Video content processing workflow}
  spec.homepage      = "http://voyz.es"
  spec.license       = ""

  spec.files         = `git ls-files -z`.split("\x0")
  spec.bindir        = 'bin'
  spec.executables   = ["cpw"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "minitest", "~> 5.5"
  spec.add_development_dependency "test-unit", "~> 3.0"
  spec.add_development_dependency "mocha"
  spec.add_development_dependency "webmock"

  spec.add_dependency "pocketsphinx-ruby", ["~> 0.3.0", '< 1']
  spec.add_dependency "multi_json"
  spec.add_dependency "spyke"
  spec.add_dependency "faraday"
  spec.add_dependency "dotenv"
  spec.add_dependency "aws-sdk-v1"
  spec.add_dependency "mono_logger"
  spec.add_dependency "shoryuken"
  spec.add_dependency "chronic"

  spec.add_runtime_dependency('gli', '2.13.0')
end
