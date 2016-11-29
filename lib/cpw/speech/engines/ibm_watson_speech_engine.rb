module CPW
  module Speech
    module Engines

      # https://www.ibm.com/watson/developercloud/speech-to-text.html
      # https://www.ibm.com/watson/developercloud/speech-to-text/api/v1/
      # https://github.com/watson-developer-cloud/speech-to-text-websockets-ruby
      class IbmWatsonSpeechEngine < Base
        attr_accessor :api_version, :method, :username, :password,
          :token, :sampling_rate

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options

          self.token         = nil
          self.sampling_rate = options[:sampling_rate] || 16000
          self.method        = options[:method] || :sessionless
          self.api_version   = options[:api_version] || ENV.fetch('IBM_WATSON_SPEECH_API_VERSION', 'v1')
          self.username      = options[:username] || ENV.fetch('IBM_WATSON_SPEECH_USERNAME', nil)
          self.password      = options[:password] || ENV.fetch('IBM_WATSON_SPEECH_PASSWORD', nil)
        end

        protected

        def reset!(options = {})
          super options

          # authorize!
        end

        def encode(chunk)
          chunk.build.to_flac
        end

        def convert_chunk(chunk, options = {})
          logger.info "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          retrying    = true
          retry_count = 0
          result      = {'status' => chunk.status}

          base_url = "https://stream.watsonplatform.net/speech-to-text/api/#{api_version}/recognize"
          params = {
            'model' => prepare_model(locale),
            'continuous' => true,
            'inactivity_timeout' => 30,
            'max_alternatives' => 3,
            'word_alternatives_threshold' => 0.01,
            'word_confidence' => true,
            'timestamps' => true,
            'profanity_filter' => false,
            'smart_formatting' => true
          }

          url     = Curl::urlalize(base_url, params)
          service = Curl::Easy.new(url)
          service.ssl_verify_peer = false
          service.http_auth_types = :basic
          service.username        = self.username
          service.password        = self.password
          service.verbose         = self.verbose

          logger.info params.inspect if self.verbose

          # headers
          service.headers['Content-Type'] = "audio/flac"
          service.headers['User-Agent']   = USER_AGENT

          while retrying && retry_count < max_retries # 3 retries
            # request
            service.post_body = chunk.to_flac_bytes
            service.http_post

            if service.response_code == 200
              response = JSON.parse(service.body_str) rescue {}
              case api_version
              when "v1"
                parse_response_v1(chunk, response, result)
              else
                raise "Unsupported API version."
              end
              retrying = false
            else
              logger.info "#{service.response_code} from IBM Watson Speech retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep 0.5 # wait longer on error?, Google?
            end
          end

          logger.info "#{segments} processed: #{result.inspect} from: #{service.body_str.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          result['errors'] = (chunk.errors << ex.message.to_s.gsub(/\n|\r/, ""))
        ensure
          chunk.clean
          chunk.normalized_response = result
          return result
        end

        private

        # V1 result
        # {
        #    "results": [
        #       {
        #          "word_alternatives": [
        #             {
        #                "start_time": 2.4,
        #                "alternatives": [
        #                   {
        #                      "confidence": 0.9902,
        #                      "word": "severe"
        #                   }
        #                ],
        #                "end_time": 2.74
        #             },
        #             {
        #                "start_time": 2.74,
        #                "alternatives": [
        #                   {
        #                      "confidence": 0.9901,
        #                      "word": "thunderstorms"
        #                   }
        #                ],
        #                "end_time": 3.53
        #             },
        #             {
        #                "start_time": 6.85,
        #                "alternatives": [
        #                   {
        #                      "confidence": 0.9988,
        #                      "word": "on"
        #                   }
        #                ],
        #                "end_time": 7.0
        #             },
        #             {
        #                "start_time": 7.0,
        #                "alternatives": [
        #                   {
        #                      "confidence": 0.9739,
        #                      "word": "Sunday"
        #                   }
        #                ],
        #                "end_time": 7.71
        #             }
        #          ],
        #          "alternatives": [
        #             {
        #                "timestamps": [
        #                   [
        #                      "the",
        #                      0.03,
        #                      0.09
        #                   ],
        #                   [
        #                      "latest",
        #                      0.09,
        #                      0.6
        #                   ],
        #                   [
        #                      "weather",
        #                      0.6,
        #                      0.85
        #                   ],
        #                   [
        #                      "report",
        #                      0.85,
        #                      1.52
        #                   ],
        #                   [
        #                      "a",
        #                      1.81,
        #                      1.96
        #                   ],
        #                   [
        #                      "line",
        #                      1.96,
        #                      2.31
        #                   ],
        #                   . . .
        #                   [
        #                      "on",
        #                      6.85,
        #                      7.0
        #                   ],
        #                   [
        #                      "Sunday",
        #                      7.0,
        #                      7.71
        #                   ]
        #                ],
        #                "confidence": 0.967,
        #                "transcript": "the latest weather report a line of severe thunderstorms with several possible tornadoes is approaching Colorado on Sunday "
        #             }
        #          ],
        #          "final": true
        #       }
        #    ],
        #    "result_index": 0
        # }
        def parse_response_v1(chunk, data, result = {})
          chunk.raw_response        = data
          result['position']        = chunk.position
          result['id']              = chunk.id
          if data['results'] && data['results'].is_a?(Array)
            result['hypotheses']    = data['results'].map {|r| r['alternatives'].map {|a| {'utterance' => a['transcript'], 'confidence' => a['confidence']}}}.flatten
            result['hypotheses'].reject! {|a| !a['confidence'].is_a?(Float)}
            result['hypotheses'].sort! {|x, y| y['confidence'] || 0 <=> x['confidence'] || 0}

            parse_words_v1(chunk, data, result)

            chunk.status            = result['status'] = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['hypotheses'].first['utterance']
            chunk.best_score        = result['hypotheses'].first['confidence']
            self.score              += chunk.best_score
            self.segments           += 1

            logger.info data['results'].inspect if self.verbose
          elsif data['error']
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
            result['external_error'] = data['error']
          else
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
          result
        end

        def parse_words_v1(chunk, data, result = {})
          raw_words = data['results'].map {|r| r['alternatives'].map {|a| {'confidence' => a['confidence'], 'word_confidence' => a['word_confidence'], 'timestamps' => a['timestamps']}}}.flatten
          raw_words.reject! {|a| a['confidence'].nil? || a['word_confidence'].nil? || a['timestamps'].nil?}
          raw_words.sort! {|x, y| y['confidence'] || 0 <=> x['confidence'] || 0}
          if best_words = raw_words[0]
            parsed_words = []
            best_words['word_confidence'].each_with_index do |wc, i|
              wc_word       = wc[0]
              wc_confidence = wc[1]
              ts_word       = best_words['timestamps'][i][0]
              ts_start_time = best_words['timestamps'][i][1]
              ts_end_time   = best_words['timestamps'][i][2]
              if (wc_word == ts_word)
                parsed_words.push({p: i + 1, w: wc_word, c: wc_confidence, s: ts_start_time, e: ts_end_time})
              end
            end
            chunk.words = AudioChunk::Words.parse(parsed_words)
            result['words'] = chunk.words.as_json unless chunk.words.empty?
          end
          result
        end

        def prepare_model(input_locale)
          model_portion  = sampling_rate.to_i >= 16000 ? "BroadbandModel" : "NarrowbandModel"
          locale_portion = case input_locale
          when /en-GB/ then "en-UK"  # IBM mistake, normalize
          else
            input_locale
          end
          "#{locale_portion}_#{model_portion}"
        end

        def supported_locales
          ["ar-AR", "en-GB", "en-US", "es-ES", "fr-FR", "ja-JP",
            "pt-BR", "zh-CN", "zh-CN"]
        end

        private

        def authorize!
          # authorize
          token_response = nil
          uri = URI.parse("https://stream.watsonplatform.net/authorization/api/v1/token?url=https://stream.watsonplatform.net/speech-to-text/api")
          Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
            request = Net::HTTP::Get.new(uri)
            request.basic_auth self.username, self.password
            token_response = http.request(request)
          end
          self.token = token_response.body
        end
      end
    end
  end
end
