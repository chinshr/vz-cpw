module CPW
  module Speech
    module Engines

      # https://apis.voicebase.com/developer-portal
      class VoicebaseEngine < SpeechEngine
        attr_accessor :api_version, :auth_key, :auth_secret, :auth_token,
          :client, :transcription_type, :media_url, :media_id,
          :srt_transcript, :json_transcript, :external_id,
          :voicebase_response

        def initialize(url_or_file, options = {})
          super url_or_file, options

          self.api_version        = options[:api_version] || ENV.fetch('VOICEBASE_API_VERSION', '1.1')
          self.transcription_type = options[:transcription_type] || ENV.fetch('VOICEBASE_DEFAULT_TRANSCRIPTION_TYPE', 'machine')
          self.auth_key           = options[:auth_key] || ENV['VOICEBASE_API_KEY']
          self.auth_secret        = options[:auth_secret] || ENV['VOICEBASE_API_SECRET']
          self.auth_token         = options[:auth_token] || ENV['VOICEBASE_API_TOKEN']
          self.external_id        = options[:external_id]
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

        def split(splitter)
          audio_chunks = []
          upload_entire_media_when_ready
          if fetch_transcripts_or_retry
            srt_file = SRT::File.parse(srt_transcript)
            srt_file.lines.each do |srt_line|
              audio_chunk = AudioChunk.new(splitter,
                decode_start_time(srt_line),
                decode_duration(srt_line), {
                  position: srt_line.sequence,
                  raw_response: build_raw_response_from_srt_line(srt_line)
                }
              )
              audio_chunk.processed_stages = [:build, :encode]
              audio_chunks << audio_chunk
            end
          end
          audio_chunks
        end

        protected

        def reset!(options = {})
          self.client = new_client(options)

          super(options)

          if self.split_method != :auto
            # already split by other methods, now upload chunks
            upload_chunks
          end
        end

        def convert(chunk, options = {})
          result = {'status' => (chunk.status = ::Speech::State::STATUS_PROCESSING)}
          chunk.processed_stages << :convert

          if chunk.raw_response.present?
            # process split :auto from entire media file upload
            parse_chunk_raw_response(chunk, chunk.raw_response, result)
            logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
          elsif chunk.external_id
            # process chunked upload
            retrying    = true
            retry_count = 0

            logger.info "convert chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
            while retrying && retry_count < max_poll_retries
              if !chunk.poll_at || (chunk.poll_at && chunk.poll_at < Time.now)
                transcript_response = get_transcript(media_id: chunk.external_id, format: "json")
                if transcript_response.success? && transcript_response.transcript_ready?
                  raw_words_response = transcript_response.transcript
                  case api_version.to_s
                  when /1\.[0-9]{1,2}/  # v1.x
                    parse_chunk_words_response(chunk, raw_words_response, result)
                  when /2\.[0-9]{1,2}/  # v2.x
                    parse_chunk_words_response(chunk, raw_words_response, result)
                  else
                    raise NotImplementedError, "Unsupported API version `#{api_version}`."
                  end
                  retrying = false
                else
                  logger.info "Error, retry after #{poll_retry_delay} seconds" if self.verbose
                  retry_count += 1
                  sleep poll_retry_delay
                end
              else
                sleep (chunk.poll_at - Time.now) + 0.1
              end
            end
            raise TimeoutError, "too many get_transcript retries" if retry_count == max_poll_retries
            logger.info "chunk #{chunk.position} processed: #{result.inspect} from: #{service.body_str.inspect}" if self.verbose
          else
            result['status'] = chunk.status = ::Speech::State::STATUS_PROCESSING_ERROR
          end
        rescue Exception => ex
          result['status'] = chunk.status = ::Speech::State::STATUS_PROCESSING_ERROR
          add_chunk_error(chunk, ex, result)
        ensure
          chunk.normalized_response.merge!(result)
          return result
        end

        def parse_chunk_words_response(chunk, raw_words, result = {})
          chunk.raw_response     = raw_words.is_a?(String) ? raw_words : raw_words.to_json
          result['position']     = chunk.position
          result['id']           = chunk.id

          words = CPW::Speech::Engines::VoicebaseEngine::Words.parse(raw_words)
          if words.errors.empty?
            chunk.best_text      = words.to_s
            chunk.best_score     = words.confidence
            result['hypotheses'] = [{'utterance' => chunk.best_text, 'confidence' => chunk.best_score}]
            chunk.words          = words
            result['words']      = words.as_json
            result['status']     = chunk.status = ::Speech::State::STATUS_PROCESSED

            logger.info "result #{result.inspect}" if self.verbose
          else
            chunk.status         = ::Speech::State::STATUS_PROCESSING_ERROR
          end
          result
        end

        def parse_chunk_raw_response(chunk, raw_data, result = {})
          data                 = raw_data
          result['position']   = chunk.position
          result['id']         = chunk.id

          if data.key?('text')
            parse_words(chunk, data['words'], result)

            result['hypotheses'] = [{'utterance' => data['text'], 'confidence' => chunk.best_score}]
            result['status']     = chunk.status = ::Speech::State::STATUS_PROCESSED
            chunk.best_text      = data['text']

            logger.info "result #{result.inspect}" if self.verbose
          else
            chunk.status         = ::Speech::State::STATUS_PROCESSING_ERROR
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

        def upload_entire_media_when_ready
          if external_id && !transcript_ready?(0)
            upload_entire_media
          elsif !external_id && !media_id
            upload_entire_media
          end
        end

        def upload_entire_media(retries = max_retries)
          self.voicebase_response = client.upload_media({
            transcription_type: transcription_type,
            language: prepare_locale(locale)
          }.tap {|o|
            if media_url
              o[:media_url] = media_url
            elsif media_file
              if api_version.to_i < 2
                # v1.x
                o[:file] = File.new(media_file)
              else
                # v2.x
                o[:media_file] = File.new(media_file)
              end
            end
            o[:external_id] = external_id if external_id
          })

          if voicebase_response.success?
            # noop
          else
            if retries > 0
              sleep retry_delay
              upload_entire_media(retries - 1)
            else
              raise TimeoutError, "too many #upload_entire_media retries, response #{voicebase_response.inspect}"
            end
          end
        end

        def upload_chunks(retries = max_retries)
          chunks.each do |chunk|
            chunk.build.to_wav
            upload_chunk(chunk, retries)
          end
        end

        def upload_chunk(chunk, retries = max_retries)
          upload_response = nil
          retrying        = true
          retry_count     = 0

          while retrying && retry_count < retries
            upload_response = client.upload_media({
              transcription_type: transcription_type
            }.tap {|o|
              if api_version.to_i < 2
                # v1.x
                o[:file] = File.new(chunk.wav_file_name)
              else
                # v2.x
                o[:media_file] = File.new(chunk.wav_file_name)
              end
            })

            if upload_response.success?
              chunk.external_id = upload_response.media_id
              check_wait        = 5
              chunk.poll_at     = Time.now + check_wait
              retrying = false
            else
              retry_count += 1
              if retry_count >= retries
                raise TimeoutError, "too many upload retries, response #{upload_response.inspect}"
              else
                sleep retry_delay
              end
            end
          end
          upload_response
        end

        def new_client(options = {})
          self.client = if api_version.to_f < 2.0
            # V1
            ::Voicebase::Client.new({
              user_agent: user_agent,
              api_version: api_version,
              locale: prepare_locale(options[:locale] || "en-US")
            }.tap {|o|
              o[:token]       = auth_token if auth_token
              o[:auth_key]    = auth_key if auth_key
              o[:auth_secret] = auth_secret if auth_secret
            })
          else
            # V2
            # Only supports bearer token authentication for now,
            # tokens cannot be generated through authencation API,
            # tokens are requested on https://apis.voicebase.com/developer-portal
            ::Voicebase::Client.new({
              user_agent: user_agent,
              api_version: api_version,
              locale: prepare_locale(options[:locale] || "en-US")
            }.tap {|o|
              o[:token] = auth_token if auth_token
            })
          end
        end

        def fetch_transcripts
          self.voicebase_response = get_transcript(format: "srt")
          if voicebase_response.success?
            self.srt_transcript = voicebase_response.transcript
            # now, get the JSON transcript
            self.voicebase_response = get_transcript(format: "json")
            if voicebase_response.success?
              self.json_transcript = if voicebase_response.transcript.is_a?(String)
                JSON.parse(voicebase_response.transcript)
              else
                voicebase_response.transcript
              end
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
          client.get_transcript({
            format: "json"
          }.tap {|o|
            if api_version.to_i < 2
              # v1.x
              external_id ? o[:external_id] = external_id : o[:media_id] = media_id
            else
              # v2.x
              o[:media_id] = media_id
            end
          }.merge(options))
        end

        def delete_file
          if api_version.to_i < 2
            # v1.x
            if external_id
              self.voicebase_response = client.delete_file({
                external_id: external_id
              })
            elsif media_id
              self.voicebase_response = client.delete_file({
                media_id: media_id
              })
            end
          else
            # v2.x
            if media_id
              self.voicebase_response = client.delete_file({
                media_id: media_id
              })
            end
          end
        end

        def transcript_ready?(retries = max_poll_retries)
          # fetched transcript already?
          return true if self.media_id
          # otherwise...
          if api_version.to_i < 2
            # v1.x
            self.voicebase_response = client.get_file_status({}.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id})
          else
            # v2.x
            self.voicebase_response = client.get_media({}.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id})
          end

          success = (api_version.to_i < 2 && !!voicebase_response && voicebase_response.success? && voicebase_response.file_status == "MACHINECOMPLETE") ||
            (api_version.to_i >= 2 && !!voicebase_response && voicebase_response.success? && voicebase_response.parsed_response.try(:[], 'media').try(:[], 0).try(:[], 'status') == "finished")

          # success?
          if success
            self.media_id ||= if api_version.to_i >= 2
              # v2.x
              voicebase_response.parsed_response.try(:[], 'media').try(:[], 0).try(:[], 'mediaId')
            end
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

        def decode_start_time(srt_line)
          srt_line.start_time
        end

        def decode_end_time(srt_line)
          srt_line.end_time
        end

        def decode_duration(srt_line)
          decode_end_time(srt_line) - decode_start_time(srt_line)
        end

        def build_raw_response_from_srt_line(srt_line)
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
          if api_version.to_f < 2.0
            # v1.x
            case input_locale
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
          else
            # v2.x
            case input_locale
            when /en-UK/ then "en-UK"
            when /en-GB/ then "en-UK"
            when /en-AU/ then "en-AU"
            when /en/ then "en-US"
            when /es-MX/ then "es-LA"
            when /es-ES/ then "es-LA"
            when /es/ then "es-LA"
            when /pt-BR/ then "pt-BR"
            when /pt/ then "pt-BR"
            else
              raise UnsupportedLocaleError, "Unsupported language."
            end
          end
        end

        def supported_locales
          if api_version.to_f < 2.0
            ["en-US", "en-GB", "es-ES", "es-ES", "es-MX", "de-DE", "fr-FR", "it-IT", "nl-NL"]
          else
            ["en-US", "en-UK", "en-AU", "es-LA", "pt-BR"]
          end
        end
      end # VoicebaseEngine
    end
  end
end
