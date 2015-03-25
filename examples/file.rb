require 'pocketsphinx-ruby'

recognizer = Pocketsphinx::AudioFileSpeechRecognizer.new

recognizer.recognize('examples/assets/audio/goforward.raw') do |speech|
  puts speech # => "go forward ten meters"
end