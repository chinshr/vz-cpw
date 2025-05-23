module CPW
  module Speech
    module Engines

      # https://cloud.google.com/speech/
      # https://cloud.google.com/speech/docs/getting-started
      # https://cloud.google.com/speech/limits
      class GoogleCloudSpeechEngine < SpeechEngine
        attr_accessor :base_url, :api_key, :api_version, :api_method

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options
          self.api_key          = options[:api_key] || ENV['GOOGLE_CLOUD_SPEECH_API_KEY']
          self.api_version      = options[:api_version] || ENV['GOOGLE_CLOUD_SPEECH_API_VERSION'] || "v1beta1"
          self.api_method       = options[:api_method] || ENV['GOOGLE_CLOUD_SPEECH_API_METHOD'] || "syncrecognize"
          self.split_method     = options[:split_method] || :basic
        end

        protected

        def reset!(options = {})
          super options

          self.base_url = case api_version
          when "v1beta1" then
            "https://speech.googleapis.com/#{api_version}/speech:#{self.api_method}"
          else
            raise UnsupportedApiError, "Unsupported API version `#{api_version}`."
          end
          self.base_url += "?key=#{api_key}" if api_key
        end

        def encode(chunk)
          super(chunk)
          chunk.build.to_flac
        end

        def convert(chunk, options = {})
          logger.info "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          result       = {'status' => (chunk.status = ::Speech::State::STATUS_PROCESSING)}
          chunk.processed_stages << :convert
          retrying     = true
          retry_count  = 0

          service = Curl::Easy.new(base_url)
          service.verbose = self.verbose
          service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true} if self.verbose

          # headers
          service.headers['Content-Type'] = "application/json"
          service.headers['User-Agent']   = "Mozilla/5.0" # user_agent

          # body
          encode = Base64.strict_encode64(chunk.to_flac_bytes)
          body = {
            'config' => {
              'encoding' => "FLAC",
              'sampleRate' => chunk.flac_rate,
              'languageCode' => locale,
              'maxAlternatives' => 3,
              'profanityFilter' => false,
              'speechContext' => {
                'phrases' => []
              }
            },
            'audio' => {
              'content' => encode.force_encoding(Encoding::ASCII_8BIT)
            }
          }

          service.post_body = body.to_json
          logger.info body.inspect if self.verbose

          while retrying && retry_count < max_retries # 3 retries
            # request
            service.http_post

            if service.response_code == 500
              logger.info "500 from Google retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep retry_delay
            else
              response = JSON.parse(service.body_str) rescue {}
              case api_version
              when "v1beta1"
                parse_response_v1beta1(chunk, response, result)
              else
                raise UnsupportedApiError, "Unsupported API version `#{api_version}`."
              end
              retrying = false
            end
          end

          logger.info "chunk #{chunk.position} processed: #{result.inspect} from: #{service.body_str.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = ::Speech::State::STATUS_PROCESSING_ERROR
          add_chunk_error(chunk, ex, result)
        ensure
          chunk.normalized_response.merge!(result)
          return result
        end

        private

        # V1beta1 response
        #
        # {
        #   "results":[
        #     {
        #       "alternatives":[
        #         {
        #           "transcript":"this is a test",
        #           "confidence":0.97321892
        #         },
        #         {
        #           "transcript":"this is a test for"
        #           "confidence":0.94321892
        #         }
        #       ],
        #       "isFinal":true,
        #       "stability":0.97321892
        #     },
        #     {
        #       ...
        #     }
        #   ],
        #   "resultIndex":0
        #   "endpointerType":"END_OF_UTTERANCE"
        # }
        #
        def parse_response_v1beta1(chunk, data, result = {})
          chunk.raw_response        = data
          result['position']        = chunk.position
          result['id']              = chunk.id
          result['external_status'] = data['endpointerType']
          if data['results'] && data['results'].is_a?(Array)
            result['hypotheses']    = data['results'].map {|r| r['alternatives'].map {|a| {'utterance' => a['transcript'], 'confidence' => a['confidence']}}}.flatten
            result['hypotheses'].sort! {|x, y| y['confidence'] || 0 <=> x['confidence'] || 0}

            chunk.status            = result['status'] = ::Speech::State::STATUS_PROCESSED
            chunk.best_text         = result['hypotheses'].first['utterance']
            chunk.best_score        = result['hypotheses'].first['confidence'] || default_chunk_score
            logger.info data['results'].inspect if self.verbose
          elsif data['error']
            chunk.status = ::Speech::State::STATUS_PROCESSING_ERROR
            result['external_error'] = data['error']
          else
            chunk.status = ::Speech::State::STATUS_PROCESSING_ERROR
          end
          result
        end

        def supported_locales
          ["af-ZA", "cs-CZ", "da-DK", "de-DE", "en-AU", "en-GB",
            "en-IN", "en-IE", "en-NZ", "en-PH", "en-US", "es-AR",
            "es-BO", "es-CL", "es-EC", "es-SV", "es-GT", "es-NI",
            "es-PR", "es-UY", "es-VE", "fr-FR", "gl-ES", "hr-HR",
            "is-IS", "it-IT", "hu-HU", "pl-PL", "sl-SI", "fi-FI",
            "sv-SE", "vi-VN", "el-GR", "sr-RS", "he-IL", "ar-IL",
            "ar-BH", "ar-DZ", "ar-OM", "ar-QA", "ar-LB", "ar-EG",
            "fa-IR", "hi-IN", "th-TH", "ko-KO", "cmn-Hant-TW",
            "yue-Hant-HK", "ja-JP", "cmn-Hans-HK", "cmn-Hans-CN"]
        end
      end
    end
  end
end
