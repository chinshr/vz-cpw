require "curb"
require "json"
require "uuid"

require "diarize"
require "pocketsphinx-ruby"
require "cpw/pocketsphinx/audio_file_speech_recognizer"
begin
  require "voicebase"
rescue LoadError => error
end
require "srt"

require "cpw/speech/audio_inspector"
require "cpw/speech/audio_splitter"
require "cpw/speech/audio_chunk"
require "cpw/speech/audio_chunk/word"
require "cpw/speech/audio_to_text"
require "cpw/speech/engines/base"

Dir[File.dirname(__FILE__) + "/speech/engines/**/*.rb"].each {|file| require file}
