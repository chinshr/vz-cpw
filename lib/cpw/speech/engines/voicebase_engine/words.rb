require_relative "../voicebase_engine"

module CPW
  module Speech
    module Engines
      class VoicebaseEngine::Words < CPW::Speech::AudioChunk::Words

        class << self
          def parse_array_of_hashes(array_of_hashes)
            result = new

            raise ParseError, "Invalid format" unless array_of_hashes.is_a?(Array) || array_of_hashes.all? {|h| h.is_a?(Hash)}
            array_of_hashes.each_with_index do |word_hash, index|
              word = CPW::Speech::AudioChunk::Word.new(word_hash)
              result.words << word unless word.empty?
              validate_word(word, index)

              # convert
              word.start_time   = word.start_time / 1000.to_f if word.start_time
              word.end_time     = word.end_time / 1000.to_f if word.end_time
              word.duration     = word.end_time - word.start_time if word.end_time && word.start_time
            end
            result
          end

          def required_keys
            %w(p c s e w)
          end
        end # Class

        def to_json(format = nil)
          if format && format.to_sym == :voicebase
            map do |w|
              h = w.to_hash
              h[:s] *= 1000
              h[:s] = h[:s].to_i
              h[:e] *= 1000
              h[:e] = h[:e].to_i
              h
            end.to_json
          else
            super
          end
        end

      end # VoicebaseEngine::Words
    end
  end
end
