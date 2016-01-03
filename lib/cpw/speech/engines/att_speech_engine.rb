=begin
module CPW
  module Speech
    module Engines
      class AttSpeechEngine < Base
        include ::Att::Codekit

        FQDN  = "https://api.att.com"

        attr_accessor :api_key, :secret_key, :oauth, :token, :service, :mode

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options

          self.api_key       = options[:api_key] if options.key?(:api_key)
          self.secret_key    = options[:secret_key] if options.key?(:secret_key)
          self.oauth         = Auth::ClientCred.new(FQDN, api_key, secret_key)
          self.mode          = options.key?(:mode) ? options[:mode] : "standard"  # standard || custom
        end

        protected

        def reset!(options = {})
          super options
          self.token   = oauth.createToken(scope)
          self.service = Service::SpeechService.new(FQDN, token)
        end

        def build(chunk)
          chunk.build.to_wav
        end

        # Speech Context
        #
        # Specifies the speech context being applied to the transcribed text. The acceptable values for this parameter are:
        #
        # Options:
        #     dictionary_file: file path to dictionary file
        #     grammar_file: file path to grammar file
        #     speech_context: "BusinessSearch" | "Gaming" | "Generic" | "QuestionAndAnswer" |
        #       "SMS" | "SocialMedia" | "TV" | "VoiceMail" | "WebSearch"
        #
        #     speech_sub_context: "Chat" | "AlphadigitList" || ... see more at https://developer.att.com/apis/speech/docs
        #       only for context: = "Gaming", sub context makes sense.
        #
        #     content_language (Content-Language): "en-US", "es-US"
        #
        def convert_chunk(chunk, options = {})
          puts "sending chunk of size #{chunk.duration}, locale: #{locale}..." if self.verbose
          retrying            = true
          retry_count         = 0
          result              = {'status' => chunk.status}
          dictionary, grammar = load_files(options)
          service_options     = {}.merge(options)

          service_options[:xargs] = if service_options[:xargs]
            "#{service_options[:xargs]},NumResults=#{max_results}"
          else
            "NumResults=#{max_results}"
          end

          while retrying && retry_count < max_retries # 3 retries

            response = if mode == "standard"
              service.stdSpeechToText(chunk.wav_chunk, service_options)
            elsif mode == "custom"
              service_options = {
                :content_language => locale
              }.merge(service_options)
              service.customSpeechToText(chunk.wav_chunk, dictionary, grammar, service_options)
            else
              raise "Unsupported ATT speech engine ASR mode: '#{mode}'."
            end

            if response.status != "OK"
              puts "'Speech Not Recognized' from ATT retry after 0.5 seconds" if self.verbose
              retrying    = true
              retry_count += 1
              sleep 0.5
            else
              # [{"confidence"=>0.11, "grade"=>"accept", "hypothesis"=>"mikos done any shows saturday night", "language"=>"en-US", "nlu_hypothesis"=>[], "result"=>"Mikos done any shows saturday night.", "scores"=>[0.03, 0.11, 0.1, 0.1, 0.31, 1], "words"=>["Mikos", "done", "any", "shows", "saturday", "night."]}]
              data                  = JSON.parse(response.nbest.to_json)
              result['id']          = chunk.id
              result['external_id'] = "#{response.id}"
              result['hypotheses']  = data.map {|ut| {'utterance' => ut['hypothesis'], 'confidence' => ut['confidence'], 'language' => ut['language'], 'scores' => ut['scores'], 'words' => ut['words']}}

              if data.first && data.first['result']
                chunk.status        = result['status'] = AudioChunk::STATUS_TRANSCRIBED
                chunk.best_text     = data.first['result']
                chunk.best_score    = data.first['confidence']
                self.score         += data.first['confidence']
                self.segments      += 1
                puts data.first['result'] if self.verbose
              end

              retrying = false
            end

            sleep 0.1 # not too fast there tiger
          end

          puts "#{segments} processed: #{result.inspect} from: #{data.inspect}" if self.verbose
        rescue Exception => ex
          result['status'] = chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          result['errors'] = (chunk.errors << ex.message.to_s.gsub(/\n|\r/, ""))
        ensure
          chunk.clean
          chunk.captured_json = result.to_json
          return result
        end

        private

        def load_files(options = {})
          dictionary = options.key?(:dictionary_file) ? options[:dictionary_file] : nil # File.join(File.dirname(__FILE__), "templates/att", "x-dictionary.xml")
          grammar    = options.key?(:grammar_file) ? options[:grammar_file] : nil # File.join(File.dirname(__FILE__), "templates/att", "x-grammar.xml")
          return [dictionary, grammar]
        end

        def scope
          mode == "custom" ? "STTC" : "SPEECH"
        end

        def supported_locales
          ["en-US"]
        end
      end
    end
  end
end
=end
