#!/usr/bin/env ruby

require "bundler/setup"
require "pocketsphinx-ruby"

include Pocketsphinx

decoder = Decoder.new(Configuration.default)
decoder.decode 'examples/assets/audio/goforward.raw'

puts decoder.hypothesis # => "go forward ten meters"

# puts decoder.hypothesis.words  # currently not working as advertized
# => [
#  #<struct Pocketsphinx::Decoder::Word word="<s>", start_frame=608, end_frame=610>,
#  #<struct Pocketsphinx::Decoder::Word word="go", start_frame=611, end_frame=622>,
#  #<struct Pocketsphinx::Decoder::Word word="forward", start_frame=623, end_frame=675>,
#  #<struct Pocketsphinx::Decoder::Word word="ten", start_frame=676, end_frame=711>,
#  #<struct Pocketsphinx::Decoder::Word word="meters", start_frame=712, end_frame=770>,
#  #<struct Pocketsphinx::Decoder::Word word="</s>", start_frame=771, end_frame=821>
# ]