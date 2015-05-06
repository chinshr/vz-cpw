module CPW
  module Speech
    module Engines
      class Base
        USER_AGENT = "Mozilla/5.0"

        attr_accessor :file, :rate, :captured_json, :score, :verbose, :segments, :chunks, :chunk_size,
          :max_results, :max_retries, :locale, :version, :logger, :base_audio_file_type

        def initialize(file, options = {})
          options.symbolize_keys!
          self.file            = file
          self.captured_json   = {}
          self.score           = 0.0
          self.segments        = 0
          self.chunks          = []
          self.chunk_size      = options[:chunk_size].to_i if options.key?(:chunk_size)
          self.verbose         = !!options[:verbose] if options.key?(:verbose)
          self.max_results     = 2
          self.max_retries     = 3
          self.locale          = "en-US"
          self.version         = options[:version] || "v1"
          self.logger          = CPW::logger
          self.base_audio_file_type = :flac
        end

        def to_text(options = {})
          to_json(options)
          chunks.map {|ch| ch.best_text}.compact.join(" ")
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
            #build(chunk)
            convert_chunk(chunk, audio_chunk_options(options))
            yield chunk if block_given?
          end

          self.score /= self.segments
          chunks
        end

        protected

        def reset!(options = {})
          self.score       = 0.0
          self.segments    = 0
          self.max_results = options[:max_results] || 2
          self.max_retries = options[:max_retries] || 3
          self.locale      = options[:locale] || "en-US"
          self.chunks      = Speech::AudioSplitter.new(file, audio_splitter_options(options)).split
        end

        def build(chunk)
          raise "Implement in engine."
        end

        def audio_splitter_options(options = {})
          {engine: self, chunk_size: chunk_size, verbose: verbose, locale: locale}.merge(options).reject {|k,v| v.blank?}
        end

        def audio_chunk_options(options = {})
          {verbose: verbose}.merge(options).reject {|k,v| v.blank?}
        end

        def convert_chunk(chunk, options = {})
          raise "Implement in engine."
        end
      end
    end
  end
end