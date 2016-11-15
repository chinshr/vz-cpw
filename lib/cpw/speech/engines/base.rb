module CPW
  module Speech
    module Engines
      class Base
        USER_AGENT = "Mozilla/5.0"

        attr_accessor :media_file, :media_url, :rate, :captured_json,
          :score, :verbose, :segments, :chunks, :chunk_duration,
          :max_results, :max_retries, :locale, :logger, :base_file_type,
          :source_file_type, :split_method, :audio_splitter

        def initialize(media_file_or_url, options = {})
          options.symbolize_keys!
          if valid_url?(media_file_or_url)
            self.media_url      = media_file_or_url
          else
            self.media_file     = media_file_or_url
          end
          self.captured_json    = {}
          self.score            = 0.0
          self.segments         = 0  # chunk_count
          self.chunks           = []
          self.chunk_duration   = options[:chunk_duration].to_i if options.key?(:chunk_duration)
          self.verbose          = !!options[:verbose]
          self.max_results      = 2
          self.max_retries      = 3
          self.locale           = "en-US"
          self.logger           = options[:logger] || CPW::logger
          self.base_file_type   = :flac
          self.source_file_type = nil
          self.split_method     = options[:split_method] || :auto
        end

        def to_text(options = {})
          to_json(options)
          chunks.map { |ch| ch.best_text }.compact.join(" ")
        end

        def to_json(options = {})
          reset! options

          chunks.each do |chunk|
            build(chunk)
            convert_chunk(chunk, audio_chunk_options(options))
            yield chunk if block_given?
          end

          self.score /= self.segments
          return {"chunks" => chunks.map {|ch| JSON.parse(ch.captured_json)}}
        end

        def perform(options = {})
          reset! options

          chunks.each do |chunk|
            build(chunk)
            convert_chunk(chunk, audio_chunk_options(options))
            yield chunk if block_given?
          end

          self.score /= self.segments
          chunks
        end

        def clean
          chunks.each {|chunk| chunk.clean} if chunks
        end

        def parse_words(chunk, words_response)
          # Will parse words from response and
          # add to chunk.words
        end

        protected

        def reset!(options = {})
          self.score            = 0.0
          self.segments         = 0
          self.max_results      = options[:max_results] || 2
          self.max_retries      = options[:max_retries] || 3
          self.locale           = options[:locale] || "en-US"
          if media_file
            self.audio_splitter = Speech::AudioSplitter.new(media_file, audio_splitter_options(options))
            self.chunks         = audio_splitter.split
          end
        end

        def convert_chunk(chunk, options = {})
          raise "Implement #convert_chunk in engine."
        end

        def build(chunk)
          # Required if chunked audio files are necessary to be "built",
          # cut and encoded before they are passed on to the decoder.
          #
          # E.g. chunk.build.to_flac
        end

        def audio_splitter_options(options = {})
          {
            engine: self,
            chunk_duration: chunk_duration,
            verbose: verbose,
            locale: locale,
            split_method: split_method
          }.merge(options).reject {|k,v| v.blank?}
        end

        def audio_chunk_options(options = {})
          {verbose: verbose}.merge(options).reject {|k,v| v.blank?}
        end

        def valid_url?(url)
          !!(url =~ URI::DEFAULT_PARSER.regexp[:ABS_URI])
        end
      end
    end
  end
end
