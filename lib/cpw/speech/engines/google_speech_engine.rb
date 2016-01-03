# -*- encoding: binary -*-
module CPW
  module Speech
    module Engines
      class GoogleSpeechEngine < Base
        attr_accessor :service, :key, :version

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options
          self.key     = options[:key]
          self.version = options[:version] || "v1"
        end

        protected

        def reset!(options = {})
          super options
          url = case version
          when "v1" then
            # "https://www.google.com/speech-api/v1/recognize?xjerr=1&client=speech2text&lang=#{locale}&maxresults=#{max_results}"
            "https://www.google.com/speech-api/v1/recognize?client=chromium&lang=#{locale}&maxresults=#{max_results}"
          else
            "https://www.google.com/speech-api/v2/recognize?output=json&lang=#{locale}"
          end
          url += "&key=#{key}" if key

          self.service = Curl::Easy.new(url)
        end

        def build(chunk)
          chunk.build.to_flac
        end

        def convert_chunk(chunk, options = {})
          puts "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          retrying    = true
          retry_count = 0
          result      = {'status' => chunk.status}

          while retrying && retry_count < max_retries # 3 retries
            service.verbose = self.verbose

            # headers
            service.headers['Content-Type'] = "audio/x-flac; rate=#{chunk.flac_rate}"
            service.headers['User-Agent']   = USER_AGENT

            # request
            service.post_body = "Content=#{chunk.to_flac_bytes}"
            service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true} if self.verbose
            service.http_post

            if service.response_code == 500
              puts "500 from google retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep 0.5 # wait longer on error?, google??
            else
              case version
              when "v1"
                parse_v1(chunk, service.body_str, result)
              else
                parse_v2(chunk, service.body_str, result)
              end

              retrying = false
            end

            sleep 0.1 # not too fast there tiger
          end

          puts "#{segments} processed: #{result.inspect} from: #{service.body_str.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          result['errors'] = (chunk.errors << ex.message.to_s.gsub(/\n|\r/, ""))
        ensure
          chunk.clean
          chunk.captured_json = result.to_json
          return result
        end

        private

        # V1 response
        #
        # {
        #   "status":0,
        #   "id":"ce178ea89f8b17d8e8298c9c7814700a-1",
        #   "hypotheses":[
        #     {"utterance"=>"I like pickles", "confidence"=>0.59408695},
        #     {"utterance"=>"I like turtles"},
        #     {"utterance"=>"I like tickles"}
        #   ]}
        # }
        #
        def parse_v1(chunk, raw_data, result = {})
          data                      = JSON.parse(service.body_str)
          result['id']              = chunk.id
          result['external_id']     = data['id']
          result['external_status'] = data['status']

          if data.key?('hypotheses') && data['hypotheses'].is_a?(Array)
            result['hypotheses']    = data['hypotheses'].map {|ut| {'utterance' => ut['utterance'], 'confidence' => ut['confidence']}}
            chunk.status            = result['status'] = AudioChunk::STATUS_TRANSCRIBED

            chunk.best_text         = result['hypotheses'].first['utterance']
            chunk.best_score        = result['hypotheses'].first['confidence']
            self.score              += result['hypotheses'].first['confidence']
            self.segments           += 1
            puts result['hypotheses'].first['utterance'] if self.verbose
          end
          result
        end

        # V2 response
        #
        # {
        #   "result":[
        #     {
        #       "alternative":[
        #         {
        #           "transcript":"this is a test",
        #           "confidence":0.97321892
        #         },
        #         {
        #           "transcript":"this is a test for"
        #         }
        #       ],
        #       "final":true
        #     }
        #   ],
        #   "result_index":0
        # }
        #
        def parse_v2(chunk, raw_data, result = {})
          data = raw_data.split(/\n/) if raw_data.present?
          data = data.map {|string| JSON.parse(string)}
          data = data.find {|json| json["result"] && !json["result"].blank?}

          result['id']              = chunk.id
          result['external_id']     = data['result_index']
          result['external_status'] = data['status']

          if data['result'] && data['result'].is_a?(Array)
            result['hypotheses']    = data['result'].map {|res| {'utterance' => res['transcript'], 'confidence' => res['confidence']}}
            result['hypotheses']    = data['result'].map {|r| r['alternative'].map {|a| {'utterance' => a['transcript'], 'confidence' => a['confidence']}}}.flatten

            result['hypotheses'].sort! {|x, y| y['confidence'] || 0 <=> x['confidence'] || 0}

            chunk.status            = result['status'] = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['hypotheses'].first['utterance']
            chunk.best_score        = result['hypotheses'].first['confidence']
            self.score              += result['hypotheses'].first['confidence']
            self.segments           += 1
            puts result['hypotheses'].first['utterance'] if self.verbose
          end
          result
        end

        def supported_locales
          ["af", "eu", "bg", "ca", "ar-EG", "ar-JO", "ar-KW", "ar-LB", "ar-QA", "ar-AE", "ar-MA", "ar-IQ", "ar-DZ", "ar-BH", "ar-LY",
           "ar-OM", "ar-SA", "ar-TN", "ar-YE", "cs", "nl-NL", "en-AU", "en-CA", "en-IN", "en-NZ", "en-ZA", "en-GB", "en-US", "fi",
           "fr-FR", "gl", "de-DE", "he", "hu", "is", "it-IT", "id", "ja", "ko", "la", "zh-CN", "zh-TW", "zh-HK", "zh-yue", "ms-MY",
           "no-NO", "pl", "pt-PT", "pt-BR", "ro-RO", "ru", "sr-SP", "sk", "es-AR", "es-BO", "es-CL", "es-CO", "es-CR", "es-DO",
           "es-EC", "es-SV", "es-GT", "es-HN", "es-MX", "es-NI", "es-PA", "es-PY", "es-PE", "es-PR", "es-ES", "es-US", "es-UY",
           "es-VE", "sv-SE", "tr", "zu"]
        end
      end
    end
  end
end