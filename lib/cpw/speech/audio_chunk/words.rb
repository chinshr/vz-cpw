module CPW
  module Speech
    class AudioChunk::Words
      include Enumerable

      class ParseError < StandardError; end

      class << self

        def parse(input, options = {})
          @debug = options.fetch(:debug, false)
          if input.is_a?(String)
            parse_string(input)
          elsif input.is_a?(::File)
            parse_file(input)
          elsif input.is_a?(Array) && input.all? {|h| h.is_a?(Hash)}
            parse_array_of_hashes(input)
          else
            raise ParseError, "Invalid input. Expected String, File, or Array (of hashes), got #{input.class.name}."
          end
        end

        private

        def parse_file(json_file)
          parse_string ::File.open(json_file, 'rb') { |f| json_file.read }
        end

        def parse_string(json_string)
          parse_array_of_hashes(::JSON.parse(json_string))
        end

        def parse_array_of_hashes(array_of_hashes)
          result = new

          raise ParseError, "Invalid format" unless array_of_hashes.is_a?(Array) || array_of_hashes.all? {|h| h.is_a?(Hash)}
          array_of_hashes.each_with_index do |word_hash, index|
            word = CPW::Speech::AudioChunk::Word.new(word_hash)
            result.words << word unless word.empty?
            validate_word(word, index)
          end
          result
        end

        def validate_word(word, index)
          required_keys.each do |field|
            if word.send(field).nil?
              word.error = "#{index}, Invalid formatting of #{field}, [#{word.to_json.inspect}]"
              $stderr.puts word.error if @debug
            end
          end
        end

        def required_keys
          %w(p c s e w)
        end
      end # Class

      attr_writer :words

      def initialize(word_array = nil)
        raise StandardError, "Expects array of word instances." if (!word_array.nil? && !word_array.is_a?(Array)) || (word_array.is_a?(Array) && !word_array.all? {|w| w.is_a?(CPW::Speech::AudioChunk::Word)})
        @words = word_array || []
      end

      def words
        @words ||= []
      end
      alias_method :to_a, :words

      def errors
        @words.map {|w| w.error if w.error}.compact
      end

      def each(&block)
        @words.each {|word| block.call(word)}
      end

      def each_with_index(&block)
        @words.each_with_index {|word, index| block.call(word, index)}
      end

      def [](index)
        @words[index]
      end

      def from(start_time)
        self.class.new(select {|w| w.start_time >= start_time})
      end

      def to(end_time)
        self.class.new(select {|w| w.end_time <= end_time})
      end

      def first
        @words.first
      end

      def last
        @words.last
      end

      def size
        @words.length
      end
      alias_method :length, :size

      def empty?
        @words.empty?
      end

      def present?
        @words.present?
      end

      def to_s
        result = ""
        each {|w| result += (w.m == "punc" ? w.word : " #{w.word}") }
        result = result.strip
        result
      end

      def to_json(format = nil)
        map {|w| w.to_hash}.to_json
      end

      def confidence
        if (count = @words.reject {|w| w.confidence.to_f.zero?}.size.to_f) && !count.zero?
          @words.reject {|w| w.confidence.to_f.zero?}.sum(&:confidence) / count
        else
          0.0
        end
      end
    end # AudioChunk::Words
  end
end
