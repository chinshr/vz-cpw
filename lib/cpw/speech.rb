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
require "iso-639"
require "alchemy_api"

require "cpw/speech/extraction_helper"
require "cpw/speech/audio_inspector"
require "cpw/speech/audio_splitter"
require "cpw/speech/audio_chunk"
require "cpw/speech/audio_chunk/word"
require "cpw/speech/audio_chunk/words"
require "cpw/speech/audio_to_text"
require "cpw/speech/engines/speech_engine"
require "cpw/speech/engines/extraction_engine"

Dir[File.dirname(__FILE__) + "/speech/engines/**/*.rb"].each {|file| require file}

class CPW::Speech::BaseError < StandardError; end
class CPW::Speech::UnknownEngineError < CPW::Speech::BaseError; end
class CPW::Speech::NotImplementedError < CPW::Speech::BaseError; end
class CPW::Speech::UnknownOperationError < CPW::Speech::BaseError; end
class CPW::Speech::UnsupportedApiError < CPW::Speech::BaseError; end
class CPW::Speech::UnsupportedLocaleError < CPW::Speech::BaseError; end
class CPW::Speech::TimeoutError < CPW::Speech::BaseError; end
class CPW::Speech::InvalidResponseError < CPW::Speech::BaseError; end
