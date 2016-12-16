module CPW
  module Speech
    module Engines
      class SpeechEngine
        include CPW::Speech::ProcessHelper

        attr_accessor :media_file, :media_url, :rate,
          :verbose, :chunks, :chunk_duration, :max_results,
          :max_retries, :locale, :logger, :base_file_type,
          :source_file_type, :split_method, :split_options,
          :audio_splitter, :max_threads, :retry_delay,
          :max_poll_retries, :poll_retry_delay, :user_agent,
          :extraction_engine, :extraction_mode, :extraction_options,
          :errors, :normalized_response, :status

        attr_writer :perform_threaded

        def initialize(media_file_or_url, options = {})
          options.symbolize_keys!
          if valid_url?(media_file_or_url)
            self.media_url         = media_file_or_url
          else
            self.media_file        = media_file_or_url
          end
          self.status              = CPW::Speech::STATUS_UNPROCESSED
          self.chunks              = []
          self.chunk_duration      = options[:chunk_duration].to_i if options.key?(:chunk_duration)
          self.verbose             = !!options[:verbose]
          self.max_results         = options[:max_results] || ENV.fetch('SPEECH_MAX_RESULTS', 2).to_i
          self.max_retries         = options[:max_retries] || ENV.fetch('SPEECH_MAX_RETRIES', 3).to_i
          self.locale              = options[:locale] ||"en-US"
          self.logger              = options[:logger] || CPW::logger
          self.base_file_type      = :flac
          self.source_file_type    = nil
          self.split_method        = options[:split_method] || :auto
          self.split_options       = options[:split_options] || {}
          self.perform_threaded    = options[:perform_threaded] || false
          self.max_threads         = options[:max_threads] || ENV.fetch('SPEECH_MAX_THREADS', 10).to_i
          self.retry_delay         = options[:retry_delay] || ENV.fetch('SPEECH_RETRY_DELAY', 1).to_f
          self.max_poll_retries    = options[:max_poll_retries] || ENV.fetch('SPEECH_MAX_POLL_RETRIES', 360).to_i
          self.poll_retry_delay    = options[:poll_retry_delay] || ENV.fetch('SPEECH_POLL_RETRY_DELAY', 5).to_f
          self.user_agent          = options[:user_agent] || "vz-cpw-speech/#{CPW::VERSION}"
          self.extraction_engine   = options[:extraction_engine]
          self.extraction_mode     = options[:extraction_mode] || :auto
          self.extraction_options  = options[:extraction_options] || {}
          self.errors              = []
          self.normalized_response = {}
        end

        def perform(options = {})
          reset! options

          # set state & stage
          self.status      = CPW::Speech::STATUS_PROCESSING
          processed_stages << :perform

          if perform_threaded?
            # parallel
            chunks.in_groups_of(max_threads).map(&:compact).each do |grouped_chunks|
              grouped_chunks.map do |chunk|
                Thread.new do
                  encode(chunk) unless chunk.encoded?
                  convert(chunk, audio_chunk_options(options)) unless chunk.converted?
                  extract(chunk, extraction_engine_options(options)) if extract_chunks? && !chunk.extracted?
                end
              end.map(&:join)
            end
            chunks.each do |chunk|
              yield chunk if block_given?
            end
          else
            # sequential
            chunks.each do |chunk|
              encode(chunk) unless chunk.encoded?
              convert(chunk, audio_chunk_options(options)) unless chunk.converted?
              extract(chunk, extraction_engine_options(options)) if extract_chunks? && !chunk.extracted?
              yield chunk if block_given?
            end
          end
          # cleanup
          normalized_response['chunks'] = chunks.map {|chunk| chunk.as_json}
          extract(self, extraction_engine_options(options)) if extract_media? && !extracted? && perform_success?
          self.status = normalized_response['status'] = CPW::Speech::STATUS_PROCESSED
          # done
          chunks
        end

        def as_json(options = {})
          perform(options) unless performed?
          normalized_response
        end

        def to_json(options = {})
          as_json(options).to_json
        end

        def to_text(options = {})
          perform(options) unless performed?
          chunks.map {|chunk| chunk.to_s}.compact.join(" ")
        end
        alias_method :to_s, :to_text

        def clean
          chunks.each {|chunk| chunk.clean}
        end

        protected

        def reset!(options = {})
          self.processed_stages   = []
          self.max_results        = options[:max_results] || 2
          self.max_retries        = options[:max_retries] || 3
          self.locale             = options[:locale] || "en-US"
          if media_file
            begin
              self.status         = CPW::Speech::STATUS_PROCESSING
              self.processed_stages << :split
              self.audio_splitter = Speech::AudioSplitter.new(media_file, audio_splitter_options(options))
              self.chunks         = audio_splitter.split
              self.status         = CPW::Speech::STATUS_PROCESSED
            rescue CPW::Speech::BaseError => error
              self.status         = CPW::Speech::STATUS_PROCESSING_ERROR
              raise error
            end
          end
        end

        def encode(chunk)
          # Required if chunked audio files are necessary to be "transcoded",
          # cut and encoded before they are passed on to the decoder.
          #
          # E.g. chunk.build.to_flac
          #
        end

        def convert(chunk, options = {})
          raise NotImplementedError, "implement #convert in speech engine."
        end

        # {split_method: :diarize, split_options: {}}
        # {extraction_engine: :ibm_watson_alchemy_engine, extraction_mode: :all, extraction_options: {
        #   include: [:keyword_extraction, {emotion: true}]
        # }}
        def extract(entity, options = {})
          result = nil
          if extraction_engine_class
            extraction_engine = extraction_engine_class.new(self, extraction_engine_options(options))
            result = extraction_engine.extract(entity)
          end
          result
        end

        def add_chunk_error(chunk, error, result = {})
          message = error.message.to_s.gsub(/\n|\r/, "")
          chunk.errors.push(message)
          result['errors'] = [] unless normalized_response['errors'].is_a?(Array)
          result['errors'].push(message)
          message
        end

        private

        def audio_splitter_options(options = {})
          {
            engine: self,
            chunk_duration: chunk_duration,
            verbose: verbose,
            locale: locale,
            split_method: split_method,
            split_options: split_options
          }.merge(options).reject {|k,v| v.blank?}
        end

        def audio_chunk_options(options = {})
          {verbose: verbose}.merge(options).reject {|k,v| v.blank?}
        end

        def valid_url?(url)
          !!(url =~ URI::DEFAULT_PARSER.regexp[:ABS_URI])
        end

        def extraction_engine_options(options = {})
          {
            include: extraction_options[:include]
          }.merge(options[:extraction_options] || {}).reject {|k,v| v.blank?}
        end

        def extraction_engine_class
          "CPW::Speech::Engines::#{self.extraction_engine.to_s.classify}".constantize if self.extraction_engine
        rescue NameError => ex
          nil
        end

        def extract_chunks?
          em = [extraction_mode].flatten.reject(&:blank?)
          em.include?(:chunks) || em.include?(:chunk) || em.include?(:all)
        end

        def extract_media?
          em = [extraction_mode].flatten.reject(&:blank?)
          em.include?(:media) || em.include?(:all)
        end

        def perform_threaded?
          !!@perform_threaded
        end

        def perform_success?
          performed? && chunks.size > 0 && chunks.all? {|ch| ch.status == CPW::Speech::STATUS_PROCESSED}
        end

      end # SpeechEngine
    end
  end
end
