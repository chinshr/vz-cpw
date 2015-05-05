module CPW
  module Speech
    module Engines
      class PocketsphinxEngine < Base
        attr_accessor :configuration

        def initialize(file, configuration, options = {})
          super file, options
          self.base_audio_file_type = :raw
          self.configuration = configuration
        end

        def split(audio_splitter)
          chunks   = []
          chunk_id = 1

          recognizer = CPW::Pocketsphinx::AudioFileSpeechRecognizer.new(configuration)
          recognizer.recognize(audio_splitter.original_file) do |decoder|
            chunks << AudioChunk.new(audio_splitter, decode_start_time(decoder),
              decode_duration(decoder), {id: chunk_id, response: build_response(decoder)})
            chunk_id += 1
          end
          chunks
        end

        protected

        def build(chunk)
          chunk.build.to_mp3
        end

        def convert_chunk(chunk, options = {})
          result = {'status' => chunk.status}
          if response
            parse(chunk, response, result)

            logger.info "#{segments} processed: #{result.inspect}" if self.verbose
          else
            result['status'] = chunk.status = AudioSplitter::AudioChunk::STATUS_TRANSCRIPTION_ERROR
            # result['errors'] = (chunk.errors << ex.message.to_s.gsub(/\n|\r/, ""))
          end
        ensure
          return result
        end

        def parse(chunk, raw_data, result = {})
          data                      = raw_data  # JSON.parse(service.body_str)
          result['id']              = chunk.id
          result['external_id']     = data['id']
          result['external_status'] = data['status']

          if data.key?('hypotheses')
            result['hypotheses']    = data['hypotheses']
            chunk.status            = result['status'] = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['hypotheses']
            # chunk.best_score        = data['confidence']
            self.score              += data['confidence'] || 0
            self.segments           += 1
            logger.info "hypothesis: #{result['hypotheses']}" if self.verbose
          end
          result
        end

        private

        def supported_locales
          ["en-US"]
        end

        def decode_start_time(decoder)
          decoder.words.first.start_frame * 10 / 1000.to_f
        end

        def decode_end_time(decoder)
          decoder.words.last.end_frame * 10 / 1000.to_f
        end

        def decode_duration(decoder)
          decode_end_time(decoder) -  decode_start_time(decoder)
        end

        def build_response(decoder)
          response = {}
          response['hypothesis'] = decoder.hypothesis
          response['path_score'] = decoder.hypothesis.path_score
          response['words']      = build_words_response(decoder)
          # response['status']     = ???
          # response['id']         = ???
          # response['confidence'] = ???
          # response['errors']     = ???
          response
        end

        def build_words_response(decoder)
          decoder.words.map do |word|
            {
              'word' => word.word,
              'start_frame' => word.start_frame,
              'end_frame' => word.end_frame,
              'start_time' => (word.start_frame * 10) / 1000.to_f,
              'end_time' => (word.end_frame * 10) / 1000.to_f,
            }
          end
        end
      end
    end
  end
end