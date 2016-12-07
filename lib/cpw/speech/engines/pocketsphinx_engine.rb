module CPW
  module Speech
    module Engines
      class PocketsphinxEngine < SpeechEngine
        attr_accessor :configuration

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options
          self.base_file_type   = :raw
          self.source_file_type = options[:source_file_type]
          self.configuration    = options[:configuration] || ::Pocketsphinx::Configuration.default
        end

        def split(audio_splitter)
          case audio_splitter.split_method
          when :auto then split_with_native_splitter_and_transcribe
          else
            splitter.split({:split_method => :diarize})
          end
        end

        protected

        def encode(chunk)
          if audio_splitter.split_method == :diarize
            chunk.build.to_raw
          end
        end

        def convert(chunk, options = {})
          result = {'status' => (chunk.status = CPW::Speech::STATUS_PROCESSING)}
          chunk.processed_stages << :convert

          if chunk.raw_response.present?
            # already transcribed, e.g. using auto pocketsphinx recognizer
            parse(chunk, chunk.raw_response, result)
            logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
          elsif chunk.encoded?
            # still needs to be transcribed using decoder
            begin
              decoder = ::Pocketsphinx::Decoder.new(self.configuration)
              decoder.decode chunk.raw_chunk
              response = build_raw_response(decoder)
              parse(chunk, response, result)
              logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
            rescue ::Pocketsphinx::API::Error => ex
              result['status'] = chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
              add_chunk_error(chunk, ex, result)
            end
          else
            result['status'] = chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
          end
        ensure
          chunk.normalized_response.merge!(result)
          chunk.clean
          return result
        end

        def parse(chunk, data, result = {})
          chunk.raw_response        = data
          result['position']        = chunk.position
          result['id']              = chunk.id
          result['external_id']     = data['id']
          result['external_status'] = data['status']

          if data.key?('hypothesis')
            result['hypothesis']    = data['hypothesis']
            result['status']        = chunk.status = CPW::Speech::STATUS_PROCESSED
            chunk.best_text         = result['hypothesis']
            chunk.best_score        = data['posterior_prob']

            parse_words(chunk, data['words']) if data.key?('words')

            logger.info "hypothesis: #{result['hypotheses']}" if self.verbose
          else
            chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
          end
          result
        end

        def parse_words(chunk, words_response)
          result, index = [], 1
          words_response.each do |word_response|
            word = AudioChunk::Word.new({
              "p" => word_response.try(:[], 'id') || index,
              "s" => word_response.try(:[], 'start_time'),
              "e" => word_response.try(:[], 'end_time'),
              "c" => word_response.try(:[], 'posterior_prob'),
              "w" => word_response.try(:[], 'word')
            })
            unless word.word == "<s>" || word.word == "</s>"
              result << word
              index += 1
            end
          end
          chunk.words = result
        end

        def split_with_native_splitter_and_transcribe
          chunks, position = [], 1
          recognizer = CPW::Pocketsphinx::AudioFileSpeechRecognizer.new(configuration)
          recognizer.recognize(audio_splitter.original_file) do |decoder|
            chunks << AudioChunk.new(audio_splitter, decode_start_time(decoder),
              decode_duration(decoder), {position: position, raw_response: build_raw_response(decoder)})
            position += 1
          end
          chunks
        end

        private

        def supported_locales
          ["en-US"]
        end

        def decode_start_time(decoder)
          (decoder.words.first.start_frame * 10) / 1000.to_f
        end

        def decode_end_time(decoder)
          (decoder.words.last.end_frame * 10) / 1000.to_f
        end

        def decode_duration(decoder)
          decode_end_time(decoder) - decode_start_time(decoder)
        end

        def build_raw_response(decoder)
          response = {}
          response['hypothesis']     = decoder.hypothesis
          response['path_score']     = decoder.hypothesis.path_score
          response['posterior_prob'] = average_posterior_probability(decoder)
          response['words']          = build_raw_words_response(decoder)
          response
        end

        def build_raw_words_response(decoder)
          decoder.words.map do |word|
            {
              'word'           => word.word,
              'start_frame'    => word.start_frame,
              'end_frame'      => word.end_frame,
              'start_time'     => (word.start_frame * 10) / 1000.to_f,
              'end_time'       => (word.end_frame * 10) / 1000.to_f,
              'acoustic_score' => word.acoustic_score,
              'language_score' => word.language_score,
              'backoff_mode'   => word.backoff_mode,
              'posterior_prob' => word.posterior_prob
            }
          end
        end

        def average_posterior_probability(decoder)
          words = decoder.words.dup
          words.delete_if {|w| %w(<s> </s>).include?(w.word)}
          if words.size > 0
            words.inject(0) {|s, w| s + w.posterior_prob} / words.size.to_f
          else
            0.0
          end
        end
      end
    end
  end
end
