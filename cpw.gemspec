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
  spec.executables   = ["cpw", "cpwd"]
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
  spec.add_development_dependency "webmock", "~> 1.21.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "foreman-monit", "~> 1.0.4"

  spec.add_dependency "pocketsphinx-ruby", ["~> 0.3.0", '< 1']
  spec.add_dependency "multi_json", "~> 1.12.1"
  spec.add_dependency "spyke", "~> 4.0.1"
  spec.add_dependency "faraday", "~> 0.9.0"
  spec.add_dependency "dotenv", "~> 2.1.1"
  spec.add_dependency "aws-sdk-v1", "~> 1.66.0"
  spec.add_dependency "mono_logger", "~> 1.1.0"
  spec.add_dependency "null-logger", "~> 0.1.3"
  spec.add_dependency "shoryuken", "~> 2.0.11"
  spec.add_dependency "chronic", "~> 0"
  spec.add_dependency "uuid", "~> 2.3.8"
  spec.add_dependency "curb", "~> 0.9.3"
  spec.add_dependency "json", "~> 1.8.3"
  spec.add_dependency "youtube-dl.rb", "~> 0.2.5"
  spec.add_dependency "srt", "~> 0.1.3"
  spec.add_dependency "voicebase-client-ruby", "~> 1.2.2"
  spec.add_dependency "webvtt-ruby", "~> 0.3.2"
  spec.add_dependency "ttml-ruby"
  spec.add_dependency "diarize-ruby", "~> 0"
  spec.add_dependency "mimemagic", "~> 0.3.2"
  spec.add_dependency "alchemy-api-rb", "~> 0"
  spec.add_dependency "iso-639", "~> 0"
  spec.add_dependency "lsh"
  spec.add_dependency "speech-stages"
  spec.add_dependency "pkg-config", "~> 1.1.7"

  spec.add_runtime_dependency "gli", "~> 2.13.0"
end
