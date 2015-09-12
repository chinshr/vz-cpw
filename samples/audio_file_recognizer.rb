# ruby -I lib/cpw.rb samples/audio_file_recognizer.rb
require 'pocketsphinx-ruby'

recognizer = Pocketsphinx::AudioFileSpeechRecognizer.new

recognizer.recognize('samples/assets/audio/goforward.raw') do |hypothesis|
  puts hypothesis # => "go forward ten meters"
  puts hypothesis.path_score  # => 0.51
end