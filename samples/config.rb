require 'pocketsphinx-ruby'

configuration = Pocketsphinx::Configuration.default
configuration.details('vad_threshold')
# => {
#   :name => "vad_threshold",
#   :type => :float,
#   :default => 2.0,
#   :value => 2.0,
#   :info => "Threshold for decision between noise and silence frames. Log-ratio between signal level and noise level."
# }

configuration['vad_threshold'] = 4

# You can find the output of `configuration.details` here for more information 
# on the various different settings.
Pocketsphinx::LiveSpeechRecognizer.new(configuration)

