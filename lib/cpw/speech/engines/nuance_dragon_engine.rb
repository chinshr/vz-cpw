module CPW
  module Speech
    module Engines
      class NuanceDragonEngine < SpeechEngine
        attr_accessor :service, :base_url, :app_id, :app_key, :device_id

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options

          self.base_url  = options.key?(:base_url) ? options[:base_url] : "https://dictation.nuancemobility.net:443"
          self.app_id    = options[:app_id] if options.key?(:app_id)
          self.app_key   = options[:app_key].gsub(/ 0x/, "") if options.key?(:app_key)
          self.device_id = options.key?(:device_id) ? options[:device_id] : "8CGoCMXyIcJosb2"
        end

        protected

        def reset!(options = {})
          super options
          url          = "#{base_url}/NMDPAsrCmdServlet/dictation?appId=#{app_id}&appKey=#{app_key}&id=#{device_id}"
          self.service = Curl::Easy.new(url)
        end

        def encode(chunk)
          chunk.build.to_wav
        end

        def convert(chunk, options = {})
          logger.info "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          result      = {'status' => (chunk.status = CPW::Speech::STATUS_PROCESSING)}
          chunk.processed_stages << :convert
          retrying    = true
          retry_count = 0

          while retrying && retry_count < max_retries # 3 retries
            service.verbose = self.verbose

            # headers
            service.headers['Content-Type']                = "audio/x-wav;codec=pcm;bit=16;rate=#{chunk.flac_rate}"
            service.headers['Accept-Topic']                = "Dictation" # Dictation or WebSearch
            if options.key?(:audio_source)
              service.headers['X-Dictation-AudioSource']   = "" # SpeakerAndMicrophone, HeadsetInOut, HeadsetBT, HeadPhone, LineOut
            end
            # service.headers['Content-Length']              = chunk.to_wav_bytes.size.to_s  # chunk.wav_size.to_s  # if not, headers['Transfer-Encoding'] = "chunked"
            # service.headers['Transfer-Encoding'] = "chunked"
            service.headers['X-Dictation-NBestListSize']   = max_results.to_s
            service.headers['Accept-Language']             = canonical_locale(locale)
            service.headers['Accept']                      = "text/plain" # "application/xml"
            service.headers['User-Agent']                  = user_agent

            # request
            service.post_body = "#{chunk.to_wav_bytes}"
            service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true } if self.verbose
            service.http_post

            if service.response_code >= 500
              logger.info "500 from Nuance retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep retry_delay
            else
              data                 = service.body_str
              data                 = data.split(/\n/) if data.present?
              result['position']   = chunk.position
              result['id']         = chunk.id
              result['hypotheses'] = data.reject(&:blank?).map {|d| {'utterance' => d.force_encoding("utf-8")}}

              if result.key?('hypotheses') && result['hypotheses'].first
                chunk.status     = result['status'] = CPW::Speech::STATUS_PROCESSED
                chunk.best_text  = result['hypotheses'].first['utterance']
                chunk.best_score = result['hypotheses'].first['confidence']
                logger.info result['hypotheses'].first['utterance'] if self.verbose
              end
              retrying = false
            end

            sleep 0.1 # not too fast there tiger
          end

          logger.info "chunk #{chunk.position} processed: #{result.inspect} from: #{data.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
          add_chunk_error(chunk, ex, result)
        ensure
          chunk.normalized_response.merge!(result)
          chunk.clean
          return result
        end

        private

        # E.g. "en-US" -> "en_US"
        def canonical_locale(locale)
          locale.gsub("-", "_") if locale
        end

        def supported_locales
          ["en-AU", "en-GB", "en-US", "ar-EG", "ar-SA", "ar-AE", "zh-HK", "ca-ES", "hr-HR", "cs-CZ", "da-DK", "nl-NL", "fi-FI",
           "fr-CA", "fr-FR", "de-DE", "el-GR", "he-IL", "hu-HU", "id-ID", "it-IT", "ja-JP", "ko-KR", "ms-MY", "cn-MA", "zh-TW",
           "no-NO", "pl-PL", "pt-BR", "pt-PT", "ro-RO", "ru-RU", "sk-SK", "es-ES", "es-MX", "es-US", "sv-SE", "th-TH", "tr-TR",
           "uk-UA", "vi-VN"]
        end
      end
    end
  end
end
