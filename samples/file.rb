require 'pocketsphinx-ruby'

recognizer = Pocketsphinx::AudioFileSpeechRecognizer.new

recognizer.recognize('examples/assets/audio/hello.wav') do |speech|
  puts speech # => "go forward ten meters"
end