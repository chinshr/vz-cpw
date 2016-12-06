module CPW
  module Speech
    module Engines
      class VoicebaseEngine < SpeechEngine
        attr_accessor :api_version, :auth_key, :auth_secret,
          :client, :transcription_type, :media_url, :media_id,
          :srt_transcript, :json_transcript, :external_id,
          :voicebase_response

        def initialize(url_or_file, options = {})
          super url_or_file, options

          self.api_version        = options[:api_version] || ENV.fetch('VOICEBASE_API_VERSION', '1.1')
          self.transcription_type = options[:transcription_type] || ENV.fetch('VOICEBASE_DEFAULT_TRANSCRIPTION_TYPE', 'machine')
          self.auth_key           = options[:auth_key] || ENV['VOICEBASE_API_KEY']
          self.auth_secret        = options[:auth_secret] || ENV['VOICEBASE_API_SECRET']
          self.external_id        = options[:external_id]
        end

        def split(splitter)
          result = []
          upload_media_when_ready

          if fetch_transcripts_or_retry
            srt_file = SRT::File.parse(srt_transcript)
            srt_file.lines.each do |line|
              result << AudioChunk.new(splitter, decode_start_time(line),
                decode_duration(line), {position: line.sequence, raw_response: build_raw_response(line)})
            end
          end

          result
        end

        def best_score
          @best_score ||= begin
            word_set = words.select {|w| w.c >= 0 && w.c <= 1.0}
            if word_set.size > 0
              sum = word_set.sum {|w| w.c}
              sum / word_set.size.to_f
            end
          end
        end

        def clean
          super
          delete_file
        end

        protected

        def reset!(options = {})
          self.locale = options[:locale] || "en-US"
          self.client = ::VoiceBase::Client.new({
            api_version: api_version,
            auth_key: auth_key,
            auth_secret: auth_secret,
            locale: prepare_locale(locale)
          })

          super options

          self.chunks = split(self) if media_url
          self.chunks
        end

        def convert(chunk, options = {})
          result = {'status' => chunk.status}
          if chunk.raw_response.present?  # from splitter
            parse(chunk, chunk.raw_response, result)
            logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
          else
            result['status'] = chunk.status = AudioSplitter::AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
        ensure
          chunk.normalized_response.merge!(result)
          chunk.clean
          return result
        end

        def parse(chunk, raw_data, result = {})
          data                 = raw_data
          result['position']   = chunk.position
          result['id']         = chunk.id

          if data.key?('text')
            parse_words(chunk, data['words'], result)

            result['hypotheses'] = [{'utterance' => data['text'], 'confidence' => chunk.best_score}]
            result['status']     = AudioChunk::STATUS_TRANSCRIBED
            chunk.status         = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text      = data['text']

            logger.info "result #{result.inspect}" if self.verbose
          else
            chunk.status         = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
          result
        end

        def parse_words(chunk, words_response, result = {})
          words = []
          # Caution: don't normalize words again
          words = AudioChunk::Words.parse(words_response)
          # calculate confidence score
          word_set = words.reject {|w| w.confidence.to_f == 0.0}.select {|w| w.c > 0 && w.c <= 1.0}
          if word_set.size > 0
            sum = word_set.sum {|w| w.confidence}
            chunk.best_score = sum / word_set.size.to_f
          end
          chunk.words = words
          result['words'] = words.as_json
          words
        end

        private

        def upload_media_when_ready
          if external_id && !transcript_ready?(0)
            upload_media
          elsif !external_id && !media_id
            upload_media
          end
        end

        def upload_media(retries = max_retries)
          self.voicebase_response = client.upload_media({
            transcription_type: transcription_type
          }.tap {|o|
            if media_url
              o[:media_url] = media_url
            elsif media_file
              o[:file] = File.new(media_file)
            end
            o[:external_id] = external_id if external_id
          })

          if voicebase_response.success?
            self.media_id = voicebase_response.media_id
          else
            if retries > 0
              sleep retry_delay
              upload_media(retries - 1)
            else
              raise TimeoutError, "too many upload_media retries, response #{voicebase_response.inspect}"
            end
          end
        end

        def fetch_transcripts
          self.voicebase_response = get_transcript(format: "srt")
          if voicebase_response.success?
            self.srt_transcript = voicebase_response.transcript
            # now, get the JSON transcript
            self.voicebase_response = get_transcript(format: "json")
            if voicebase_response.success?
              self.json_transcript = JSON.parse(voicebase_response.transcript)
            else
              raise InvalidResponseError, "get_transcript({format: 'json'}) response #{voicebase_response.inspect}"
            end
          else
            raise InvalidResponseError, "get_transcript({format: 'srt'}) response #{voicebase_response.inspect}"
          end
        end

        def fetch_transcripts_or_retry
          if transcript_ready?
            fetch_transcripts
          else
            raise TimeoutError, "too many retries, response #{voicebase_response.inspect}"
          end
        end

        def get_transcript(options = {})
          self.voicebase_response = client.get_transcript({
            format: "json"
          }.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id}.merge(options))
        end

        def delete_file
          if client && external_id
            self.voicebase_response = client.delete_file({
              external_id: external_id
            })
          elsif client && media_id
            self.voicebase_response = client.delete_file({
              media_id: media_id
            })
          end
        end

        def transcript_ready?(retries = max_poll_retries)
          self.voicebase_response = client.get_file_status({}.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id})
          if response_success_and_machine_ready?
            true
          else
            if retries > 0
              sleep poll_retry_delay
              transcript_ready?(retries - 1)
            else
              false
            end
          end
        end

        def response_success_and_machine_ready?
          !!voicebase_response && voicebase_response.success? && voicebase_response.file_status == "MACHINECOMPLETE"
        end

        def decode_start_time(srt_line)
          srt_line.start_time
        end

        def decode_end_time(srt_line)
          srt_line.end_time
        end

        def decode_duration(srt_line)
          decode_end_time(srt_line) - decode_start_time(srt_line)
        end

        def build_raw_response(srt_line)
          response = {}
          response['text']                = srt_line.text.join(" ")
          response['start_time']          = srt_line.start_time
          response['end_time']            = srt_line.end_time
          response['sequence']            = srt_line.sequence
          response['error']               = srt_line.error if srt_line.error
          response['display_coordinates'] = srt_line.display_coordinates if srt_line.try(:display_coordinates)
          response['words']               = build_raw_words_response(srt_line)
          response
        end

        def build_raw_words_response(srt_line)
          all_words  = CPW::Speech::Engines::VoicebaseEngine::Words.parse(json_transcript)
          start_time = srt_line.start_time - 0.005
          end_time   = srt_line.end_time + 0.005
          all_words.from(start_time).to(end_time).map {|w| w.to_hash}
        end

        def prepare_locale(input_locale = self.locale)
          case input_locale
          # English
          when /en-UK/ then "en-UK"
          when /en-GB/ then "en-UK"
          when /en/ then "en"
          when /es-MX/ then "es-MEX"
          when /es-ES/ then "es"
          when /es/ then "es"
          when /de/ then "de"
          when /fr/ then "fr"
          when /it/ then "it"
          when /nl/ then "nl"
          else
            raise UnsupportedLocaleError, "Unsupported language."
          end
        end

        def supported_locales
          ["en-US", "en-GB", "es-ES", "es-ES", "es-MX", "de-DE", "fr-FR", "it-IT", "nl-NL"]
        end
      end
    end
  end
end
