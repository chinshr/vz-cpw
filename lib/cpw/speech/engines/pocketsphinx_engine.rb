module CPW
  module Speech
    module Engines
      class PocketsphinxEngine < Base
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

        def build(chunk)
          if audio_splitter.split_method == :diarize
            chunk.build.to_raw
          end
        end

        def convert_chunk(chunk, options = {})
          result = {'status' => chunk.status}
          if chunk.response
            # already transcribed, e.g. using auto pocketsphinx recognizer
            parse(chunk, chunk.response, result)
            logger.info "#{segments} processed: #{result.inspect}" if self.verbose
          elsif chunk.status == CPW::Speech::AudioChunk::STATUS_ENCODED
            # still needs to be transcribed using decoder
            begin
              decoder = ::Pocketsphinx::Decoder.new(self.configuration)
              decoder.decode chunk.raw_chunk
              chunk.response = build_response(decoder)
              parse(chunk, chunk.response, result)
              logger.info "#{segments} processed: #{result.inspect}" if self.verbose
            rescue ::Pocketsphinx::API::Error => ex
              chunk.errors.push(ex)
              result['status'] = chunk.status = CPW::Speech::AudioChunk::STATUS_TRANSCRIPTION_ERROR
            end
          else
            result['status'] = chunk.status = CPW::Speech::AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
        ensure
          chunk.clean
          chunk.captured_json = result.to_json
          return result
        end

        def parse(chunk, data, result = {})
          result['id']              = chunk.id
          result['external_id']     = data['id']
          result['external_status'] = data['status']

          if data.key?('hypothesis')
            result['hypothesis']    = data['hypothesis']
            result['status']        = AudioChunk::STATUS_TRANSCRIBED
            chunk.status            = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['hypothesis']
            chunk.best_score        = data['posterior_prob']
            self.score              += data['posterior_prob']
            self.segments           += 1
            parse_words(chunk, data['words']) if data.key?('words')

            logger.info "hypothesis: #{result['hypotheses']}" if self.verbose
          else
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
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
          chunks, chunk_id = [], 1
          recognizer = CPW::Pocketsphinx::AudioFileSpeechRecognizer.new(configuration)
          recognizer.recognize(audio_splitter.original_file) do |decoder|
            chunks << AudioChunk.new(audio_splitter, decode_start_time(decoder),
              decode_duration(decoder), {id: chunk_id, response: build_response(decoder)})
            chunk_id += 1
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

        def build_response(decoder)
          response = {}
          response['hypothesis']     = decoder.hypothesis
          response['path_score']     = decoder.hypothesis.path_score
          response['posterior_prob'] = average_posterior_probability(decoder)
          response['words']          = build_words_response(decoder)
          response
        end

        def build_words_response(decoder)
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
