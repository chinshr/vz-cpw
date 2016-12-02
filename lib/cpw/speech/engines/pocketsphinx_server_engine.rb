module CPW
  module Speech
    module Engines
      class PocketsphinxServerEngine < SpeechEngine
        attr_accessor :service, :key

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options
          self.key = options[:key]
        end

        protected

        def reset!(options = {})
          super options
          url = "http://127.0.0.1:9393/recognize?&nbest=#{max_results}"
          url += "&key=#{key}" if key

          self.service = Curl::Easy.new(url)
        end

        def encode(chunk)
          chunk.build.to_flac
        end

        def convert(chunk, options = {})
          logger.info "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          retrying    = true
          retry_count = 0
          result      = {'status' => chunk.status}

          while retrying && retry_count < max_retries # 3 retries
            service.verbose = self.verbose

            # headers
            # service.headers['Content-Type'] = "audio/x-raw-int; rate=#{chunk.flac_rate}"
            service.headers['Content-Type'] = "audio/x-flac; rate=#{chunk.flac_rate}"
            service.headers['User-Agent']   = user_agent

            # request
            service.post_body = "#{chunk.to_flac_bytes}"
            service.on_progress {|dl_total, dl_now, ul_total, ul_now| printf("%.2f/%.2f\r", ul_now, ul_total); true} if self.verbose
            service.http_post

            if service.response_code != 200  # == 500
              logger.info "#{service.response_code} from server, retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep 0.5 # wait longer on error?
            else
              parse_v1(chunk, service.body_str, result)
              retrying = false
            end

            sleep 0.1 # not too fast there tiger
          end

          logger.info "chunk #{chunk.position} processed: #{result.inspect} from: #{service.body_str.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = AudioSplitter::AudioChunk::STATUS_TRANSCRIPTION_ERROR
          add_chunk_error(chunk, ex, result)
        ensure
          chunk.normalized_response.merge!(result)
          chunk.clean
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
          result['position']        = chunk.position
          result['id']              = chunk.id
          result['external_id']     = data['id']
          result['external_status'] = data['status']

          if data.key?('hypotheses') && data['hypotheses'].is_a?(Array)
            result['hypotheses']    = data['hypotheses'].map {|ut| {'utterance' => ut['utterance'], 'confidence' => ut['confidence'] || 0}}
            chunk.status            = result['status'] = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['hypotheses'].first['utterance']
            chunk.best_score        = result['hypotheses'].first['confidence']
            logger.info result['hypotheses'].first['utterance'] if self.verbose
          end
          result
        end

        def supported_locales
          ["en-US"]
        end
      end
    end
  end
end
