module CPW
  module Speech
    module Engines
      class PocketsphinxEngine < Base
        attr_accessor :configuration

        def initialize(media_file_or_url, configuration, options = {})
          super media_file_or_url, options
          self.base_file_type   = :raw
          self.source_file_type = options[:source_file_type]
          self.configuration    = configuration
        end

        def split(splitter)
          chunks   = []
          chunk_id = 1

          recognizer = CPW::Pocketsphinx::AudioFileSpeechRecognizer.new(configuration)
          recognizer.recognize(splitter.original_file) do |decoder|
            chunks << AudioChunk.new(splitter, decode_start_time(decoder),
              decode_duration(decoder), {id: chunk_id, response: build_response(decoder)})
            chunk_id += 1
          end
          chunks
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

        protected

        def convert_chunk(chunk, options = {})
          result = {'status' => chunk.status}
          if chunk.response  # from splitter
            parse(chunk, chunk.response, result)
            logger.info "#{segments} processed: #{result.inspect}" if self.verbose
          else
            result['status'] = chunk.status = AudioSplitter::AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
        ensure
          return result
        end

        def parse(chunk, raw_data, result = {})
          data                      = raw_data  # JSON.parse(service.body_str)
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
            logger.info "hypothesis: #{result['hypotheses']}" if self.verbose
          else
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
          result
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