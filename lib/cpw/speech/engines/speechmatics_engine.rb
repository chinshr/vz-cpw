module CPW
  module Speech
    module Engines

      # https://speechmatics.com/api-details
      class SpeechmaticsEngine < SpeechEngine
        attr_accessor :base_url, :api_version, :user_id, :auth_token,
          :external_id, :job_id, :json_transcript

        def initialize(url_or_file, options = {})
          super url_or_file, options

          self.base_url      = "https://api.speechmatics.com"
          self.api_version   = options[:api_version] || ENV.fetch('SPEECHMATICS_API_VERSION', 'v1.0')
          self.user_id       = options[:user_id] || ENV['SPEECHMATICS_USER_ID']
          self.auth_token    = options[:auth_token] || ENV['SPEECHMATICS_AUTH_TOKEN']
          self.split_method  = options[:split_method] || :basic
          self.external_id   = options[:external_id]
          self.job_id        = options[:job_id]
        end

        def split(splitter)
          audio_chunks = []
          upload_entire_media_when_ready
          if fetch_transcripts_or_retry
            speakers = CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse(json_transcript)
            speakers.each do |speaker|
              audio_chunk = AudioChunk.new(
                splitter,
                speaker.start_time,
                speaker.duration, {
                  position: speaker.position,
                  raw_response: build_raw_response_from_speaker(speaker)
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
          result = super(options)
          upload_chunks
          result
        end

        def convert(chunk, options = {})
          result          = {'status' => (chunk.status = ::Speech::State::STATUS_PROCESSING)}
          chunk.processed_stages << :convert

          if chunk.raw_response.present?
            # process split :auto from entire media file upload
            parse_chunk_raw_response(chunk, chunk.raw_response, result)
            logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
          elsif chunk.external_id # i.e. job_id
            retrying        = true
            retry_count     = 0

            # service
            fetch_url       = "#{base_url}/#{api_version}/user/#{user_id}/jobs/#{chunk.external_id}/transcript?auth_token=#{auth_token}"
            service         = Curl::Easy.new(fetch_url)
            service.verbose = self.verbose

            # headers
            service.headers['Content-Type'] = "application/json"
            service.headers['User-Agent']   = user_agent

            logger.info  "convert chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose

            while retrying && retry_count < max_poll_retries
              if !chunk.poll_at || (chunk.poll_at && chunk.poll_at < Time.now)
                # request
                service.http_get

                if service.response_code == 200
                  logger.info service.body_str.inspect if self.verbose
                  response = JSON.parse(service.body_str)
                  case api_version
                  when /v1.0/
                    parse_response_v1_0(chunk, response, result)
                  else
                    raise UnsupportedApiError, "Unsupported API version `#{api_version}`."
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

        private

        def upload_entire_media_when_ready
          upload_entire_media unless transcript_ready?
        end

        def upload_entire_media(retries = max_retries)
          upload_response = {}
          retrying        = true
          retry_count     = 0
          upload_url      = "#{base_url}/#{api_version}/user/#{user_id}/jobs/?auth_token=#{auth_token}"

          service         = Curl::Easy.new(upload_url)
          service.verbose = self.verbose

          # headers
          service.headers['User-Agent']   = user_agent

          while retrying && retry_count < retries
            # form fields
            form_fields = []
            form_fields.push Curl::PostField.content('model', prepare_locale(locale))
            form_fields.push Curl::PostField.content('diarisation', "true")
            form_fields.push Curl::PostField.content('meta', "#{external_id}") if external_id
            form_fields.push Curl::PostField.content('notification', "none")
            form_fields.push Curl::PostField.file('data_file', media_file)

            # request
            service.multipart_form_post = true
            service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true} if self.verbose

            service.http_post(*form_fields)

            if service.response_code == 200
              upload_response   = JSON.parse(service.body_str)
              logger.info upload_response.inspect if self.verbose
              self.job_id       = upload_response['id']
              check_wait        = (upload_response['check_wait'] || 10).to_i
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

        def transcript_ready?(retries = max_poll_retries)
          return false unless job_id

          fetch_url       = "#{base_url}/#{api_version}/user/#{user_id}/jobs/#{job_id}/?auth_token=#{auth_token}"
          service         = Curl::Easy.new(fetch_url)
          service.verbose = self.verbose

          # headers
          service.headers['Content-Type'] = "application/json"
          service.headers['User-Agent']   = user_agent

          service.http_get
          logger.info service.body_str.inspect if self.verbose
          success  = (service.response_code == 200)
          response = JSON.parse(service.body_str)
          poll_retry_delay = response.try(:[], 'job').try(:[], 'check_wait') || poll_retry_delay

          # success?
          if success &&
              response.try(:[], 'job').try(:[], 'job_type') == "transcription" &&
              response.try(:[], 'job').try(:[], 'job_status') == "done"
            self.external_id ||= response.try(:[], 'job').try(:[], 'meta')
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

        def fetch_transcripts_or_retry
          if transcript_ready?
            fetch_transcripts
          else
            raise TimeoutError, "too many retries"
          end
        end

        def get_transcript(options = {})
          fetch_url       = "#{base_url}/#{api_version}/user/#{user_id}/jobs/#{job_id}/transcript?auth_token=#{auth_token}"
          service         = Curl::Easy.new(fetch_url)
          service.verbose = self.verbose

          # headers
          service.headers['Content-Type'] = "application/json"
          service.headers['User-Agent']   = user_agent

          service.http_get
          logger.info service.body_str.inspect if self.verbose
          success  = (service.response_code == 200)
          if success
            response = JSON.parse(service.body_str)
          else
            false
          end
        end

        def fetch_transcripts
          response = get_transcript(format: "json")
          if response
            self.json_transcript = response
          else
            raise InvalidResponseError, "get_transcript({format: 'format'}) response #{response.inspect}"
          end
        end

        def upload_chunks(retries = max_retries)
          chunks.each do |chunk|
            chunk.build.to_wav
            upload_chunk(chunk, retries)
          end
        end

        def upload_chunk(chunk, retries = max_retries)
          upload_response = {}
          retrying        = true
          retry_count     = 0
          upload_url      = "#{base_url}/#{api_version}/user/#{user_id}/jobs/?auth_token=#{auth_token}"

          service         = Curl::Easy.new(upload_url)
          service.verbose = self.verbose

          # headers
          service.headers['User-Agent']   = user_agent

          while retrying && retry_count < retries
            # form fields
            form_fields = []
            form_fields.push Curl::PostField.content('model', prepare_locale(locale))
            form_fields.push Curl::PostField.content('diarisation', "false")
            form_fields.push Curl::PostField.content('meta', "#{chunk.id}")
            form_fields.push Curl::PostField.content('notification', "none")
            form_fields.push Curl::PostField.file('data_file', chunk.wav_file_name)
            if !chunk.best_text.blank?
              # alignment
              form_fields.push Curl::PostField.file('text_file', chunk.best_text)
            end

            # request
            service.multipart_form_post   = true
            service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true} if self.verbose

            service.http_post(*form_fields)

            if service.response_code == 200
              upload_response   = JSON.parse(service.body_str)
              logger.info upload_response.inspect if self.verbose
              chunk.external_id = upload_response['id']
              check_wait        = (upload_response['check_wait'] || 10).to_i
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

        def parse_response_v1_0(chunk, data, result = {})
          chunk.raw_response     = data
          result['position']     = chunk.position
          result['id']           = chunk.id
          if data.key?('words')
            parse_words_v1_0(chunk, data['words'], result)
            chunk.best_text      = chunk.words.to_s
            chunk.best_score     = chunk.words.confidence
            result['hypotheses'] = [{'utterance' => chunk.best_text, 'confidence' => chunk.best_score}]
            result['words']      = chunk.words.as_json
            result['status']     = chunk.status = ::Speech::State::STATUS_PROCESSED

            logger.info "result #{result.inspect}" if self.verbose
          else
            chunk.status         = ::Speech::State::STATUS_PROCESSING_ERROR
          end
          result
        end

        def parse_words_v1_0(chunk, words_response, result = {})
          words = chunk.words = SpeechmaticsEngine::Words.parse(words_response)
          # calculate confidence score
          word_set = words.reject {|w| w.confidence.to_f == 0}.select {|w| w.c > 0 && w.c <= 1.0}
          if word_set.size > 0
            sum = word_set.sum {|w| w.confidence}
            chunk.best_score = sum / word_set.size.to_f
          end
          words
        end

        def prepare_locale(input_locale = self.locale)
          case input_locale
          when /en-AU/ then "en-AU"
          when /en-UK/, /en-GB/ then "en-GB"
          when /en-US/ then "en-US"
          when /ca/ then "ca"
          when /cs/ then "cs"
          when /de/ then "de"
          when /el/ then "el"
          when /el/ then "el"
          when /en/ then "en-US"
          when /es/ then "es"
          when /fi/ then "fi"
          when /fr/ then "fr"
          when /hu/ then "hu"
          when /it/ then "it"
          when /ja/ then "ja"
          when /nl/ then "nl"
          when /pl/ then "pl"
          when /pt/ then "pt"
          when /ro/ then "ro"
          when /ru/ then "ru"
          when /sv/ then "sv"
          else
            raise UnsupportedLocaleError, "Unsupported language."
          end
        end

        def supported_locales
          ["ca", "cs", "de", "el", "en-AU", "en-GB", "en-US", "en", "es",
            "fi", "fr", "hu", "it", "ja", "nl", "pl", "pt", "ro", "ru", "sv"]
        end

        def build_raw_response_from_speaker(speaker)
          response = {}
          response['text']                = speaker.words.to_s if speaker.words.present?
          response['start_time']          = speaker.start_time
          response['end_time']            = speaker.end_time
          response['sequence']            = speaker.sequence
          response['error']               = speaker.error.inspect if speaker.error.present?
          response['words']               = speaker.words.as_json if speaker.words.present?
          response
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
      end # SpeechmaticsEngine
    end
  end
end
