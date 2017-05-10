require_relative "../speechmatics_engine"

module CPW
  module Speech
    module Engines
      class SpeechmaticsEngine::Words < CPW::Speech::AudioChunk::Words

        class << self
          def parse_array_of_hashes(array_of_hashes)
            result = new

            raise ParseError, "Invalid format" unless array_of_hashes.is_a?(Array) || array_of_hashes.all? {|h| h.is_a?(Hash)}
            array_of_hashes.each_with_index do |word_hash, index|
              word = CPW::Speech::AudioChunk::Word.new(word_hash)
              word.position   = index + 1
              result.words << word unless word.empty?
              validate_word(word, index)
              convert_word(word)
            end
            result
          end

          def required_keys
            %w(p c s d w)
          end

          private

          def convert_word(word)
            word.confidence = word.confidence.to_f if word.confidence
            word.start_time = word.start_time.to_f if word.start_time
            word.duration   = word.duration.to_f if word.duration
            word.end_time   = word.start_time + word.duration if word.start_time && word.duration
            word.metadata   = "punc" if word.word.to_s.match(/^[\.\!\?\,]$/)
          end

        end # Class

        attr_writer :words

        def initialize(word_array = nil)
          raise StandardError, "Expects array of word instances." if (!word_array.nil? && !word_array.is_a?(Array)) || (word_array.is_a?(Array) && !word_array.all? {|w| w.is_a?(AudioChunk::Word)})
          @words = word_array || []
        end

        def words
          @words ||= []
        end

        def errors
          @words.map {|w| w.error if w.error}.compact
        end

        def each(&block)
          @words.each {|word| block.call(word)}
        end

        def from(start_time)
          self.class.new(select {|w| w.start_time >= start_time})
        end

        def to(end_time)
          self.class.new(select {|w| w.end_time <= end_time})
        end

        def to_a
          @words
        end

        def to_s
          result = ""
          each {|w| result += (w.m == "punc" ? w.word : " #{w.word}") }
          result = result.strip
          result
        end

        def to_json(format = nil)
          if format && format.to_sym == :speechmatics
            map do |w|
              h = {}
              h[:duration]   = w.duration.to_s
              h[:confidence] = w.confidence.to_s
              h[:name]       = w.word
              h[:time]       = w.start_time.to_s
              h
            end.to_json
          else
            super
          end
        end

      end # SpeechmaticsEngine::Words
    end
  end
end
