require 'curb'
require 'json'
require 'uuid'
require 'att/codekit'

require "cpw/speech/audio_inspector"
require "cpw/speech/audio_splitter"
require "cpw/speech/audio_chunk"
require "cpw/speech/audio_to_text"
require "cpw/speech/engines/base"

Dir[File.dirname(__FILE__) + "/speech/engines/**/*.rb"].each {|file| require file}
