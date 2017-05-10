module CPW
  module Speech
    module Engines
      class SpeechmaticsEngine::Speakers
        include Enumerable

        class ParseError < StandardError; end

        attr_writer :speakers

        class << self

          def parse(input, options = {})
            @debug = options.fetch(:debug, false)
            if input.is_a?(String)
              parse_string(input)
            elsif input.is_a?(Hash)
              parse_hash(input)
            else
              raise ParseError, "Invalid input. Expected String, or Array (of hashes), got #{input.class.name}."
            end
          end

          private

          def parse_string(transcript_string)
            raise ParseError, "Invalid format: json string empty" if transcript_string.empty?
            parse_hash(::JSON.parse(transcript_string))
          end

          def parse_hash(transcript_hash)
            result = new

            raise ParseError, "Invalid format" unless transcript_hash.is_a?(Hash)
            raise ParseError, "Invalid format, missing 'speakers'" unless transcript_hash['speakers']

            speaker_hashes = transcript_hash['speakers']
            raise ParseError, "Invalid format, 'speakers'" unless speaker_hashes.is_a?(Array) || speaker_hashes.all? {|h| h.is_a?(Hash)}

            word_hashes = transcript_hash['words']

            speaker_hashes.each_with_index do |speaker_hash, index|
              speaker = SpeechmaticsEngine::Speaker.new(speaker_hash)
              speaker.sequence  = index + 1
              if word_hashes
                words = SpeechmaticsEngine::Words.parse(word_hashes)
                speaker.words = words.from(speaker.start_time).to(speaker.end_time)
              end
              result.speakers << speaker if speaker.valid?
            end
            result
          end

        end # class

        def initialize(speaker_array = nil)
          raise StandardError, "Expects array of speaker instances." if (!speaker_array.nil? && !speaker_array.is_a?(Array)) || (speaker_array.is_a?(Array) && !speaker_array.all? {|w| w.is_a?(SpeechmaticsEngine::Speaker)})
          @speakers = speaker_array || []
        end

        def speakers
          @speakers ||= []
        end
        alias_method :to_a, :speakers

        def errors
          @speakers.map {|s| s.error unless s.valid?}.compact
        end

        def each(&block)
          @speakers.each {|s| block.call(s)}
        end

        def each_with_index(&block)
          @speakers.each_with_index {|s, index| block.call(s, index)}
        end

        def [](index)
          @speakers[index]
        end

        def from(start_time)
          self.class.new(select {|s| s.start_time >= start_time})
        end

        def to(end_time)
          self.class.new(select {|s| s.end_time <= end_time})
        end

        def first
          @speakers.first
        end

        def last
          @speakers.last
        end

        def size
          @speakers.length
        end
        alias_method :length, :size

        def empty?
          @speakers.empty?
        end

        def present?
          @speakers.present?
        end

        def to_json(format = nil)
          map {|s| s.as_json}.to_json
        end

      end # SpeechmaticsEngine::Speakers
    end
  end
end
