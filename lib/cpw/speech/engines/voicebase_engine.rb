module CPW
  module Speech
    module Engines
      class VoiceBaseEngine < Base
        attr_accessor :api_version, :auth_key, :auth_secret,
          :client, :response, :transcription_type,
          :media_url, :media_id, :srt_transcript, :json_transcript,
          :external_id

        DEFAULT_UPLOAD_MEDIA_RETRIES     = 5
        DEFAULT_FETCH_TRANSCRIPT_RETRIES = 360
        RETRY_DELAY_IN_SECONDS           = 10

        class InvalidResponseError < StandardError; end
        class TimeoutError < StandardError; end
        class UnsupportedLocale < StandardError; end

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
          prepare_media

          if fetch_transcripts_or_retry
            srt_file = SRT::File.parse(srt_transcript)
            srt_file.lines.each do |line|
              result << AudioChunk.new(splitter, decode_start_time(line),
                decode_duration(line), {id: line.sequence, response: build_response(line)})
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

        def parse_words(chunk, words_response)
          words = []
          # normalize words
          words_response.each do |word_response|
            word_response['s'] = word_response['s'] / 1000.to_f
            word_response['e'] = word_response['e'] / 1000.to_f
            words << AudioChunk::Word.new(word_response)
          end
          # calculate confidence score
          word_set = words.select {|w| w.c >= 0 && w.c <= 1.0}
          if word_set.size > 0
            sum = word_set.sum {|w| w.c}
            chunk.best_score = sum / word_set.size.to_f
          end
          chunk.words = words
        end

        protected

        def reset!(options = {})
          self.locale = options[:locale] || "en-US"
          self.client = VoiceBase::Client.new({
            api_version: api_version,
            auth_key: auth_key,
            auth_secret: auth_secret,
            locale: supported_locale
          })

          super options

          self.chunks = split(self) if media_url
          self.chunks
        end

        def convert_chunk(chunk, options = {})
          result = {'status' => chunk.status}
          if chunk.response  # from splitter
            parse(chunk, chunk.response, result)
            logger.info "#{segments} processed: #{result.inspect}" if self.verbose
          else
            result['status'] = chunk.status = AudioSplitter::AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
        ensure
          return result
        end

        def parse(chunk, raw_data, result = {})
          data                      = raw_data  # JSON.parse(service.body_str)
          result['id']              = chunk.id

          if data.key?('text')
            result['text']          = data['text']
            result['status']        = AudioChunk::STATUS_TRANSCRIBED
            chunk.status            = AudioChunk::STATUS_TRANSCRIBED
            chunk.best_text         = result['text']
            self.segments           += 1
            parse_words(chunk, data['words']) if data['words']

            logger.info "text: #{result['text']}" if self.verbose
          else
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
          end
          result
        end

        private

        def prepare_media
          if external_id && !transcript_ready?(0)
            upload_media
          elsif !external_id && !media_id
            upload_media
          end
        end

        def upload_media(retries = DEFAULT_UPLOAD_MEDIA_RETRIES)
          self.response = client.upload_media({
            transcription_type: transcription_type
          }.tap {|o|
            if media_url
              o[:media_url] = media_url
            elsif media_file
              o[:file] = File.new(media_file)
            end
            o[:external_id] = external_id if external_id
          })

          if response.success?
            self.media_id = response.media_id
          else
            if retries > 0
              sleep RETRY_DELAY_IN_SECONDS
              upload_media(retries - 1)
            else
              raise TimeoutError, "too many upload_media retries, response #{response.inspect}"
            end
          end
        end

        def fetch_transcripts
          self.response = get_transcript(format: "srt")
          if response.success?
            self.srt_transcript = response.transcript
            # now, get the JSON transcript
            self.response = get_transcript(format: "json")
            if response.success?
              self.json_transcript = JSON.parse(response.transcript)
            else
              raise InvalidResponseError, "get_transcript({format: 'json'}) response #{response.inspect}"
            end
          else
            raise InvalidResponseError, "get_transcript({format: 'srt'}) response #{response.inspect}"
          end
        end

        def fetch_transcripts_or_retry
          if transcript_ready?
            fetch_transcripts
          else
            raise TimeoutError, "too many retries, response #{response.inspect}"
          end
        end

        def get_transcript(options = {})
          self.response = client.get_transcript({
            format: "json"
          }.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id}.merge(options))
        end

        def delete_file
          if client && external_id
            self.response = client.delete_file({
              external_id: external_id
            })
          elsif client && media_id
            self.response = client.delete_file({
              media_id: media_id
            })
          end
        end

        def transcript_ready?(retries = DEFAULT_FETCH_TRANSCRIPT_RETRIES)
          self.response = client.get_file_status({}.tap {|o| external_id ? o[:external_id] = external_id : o[:media_id] = media_id})
          if response_success_and_machine_ready?
            true
          else
            if retries > 0
              sleep RETRY_DELAY_IN_SECONDS
              transcript_ready?(retries - 1)
            else
              false
            end
          end
        end

        def response_success_and_machine_ready?
          !!response && response.success? && response.file_status == "MACHINECOMPLETE"
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

        def build_response(srt_line)
          response = {}
          response['text']       = srt_line.text.join(" ")
          response['start_time'] = srt_line.start_time
          response['end_time']   = srt_line.end_time
          response['sequence']   = srt_line.sequence
          response['error']      = srt_line.error if srt_line.error
          response['display_coordinates'] = srt_line.display_coordinates if srt_line.try(:display_coordinates)
          response['words']      = build_words_response(srt_line)
          response
        end

        def build_words_response(srt_line)
          json       = VoiceBase::JSON.parse(json_transcript)
          start_time = (srt_line.start_time * 1000) - 5
          end_time   = (srt_line.end_time * 1000) + 5
          json.from(start_time).to(end_time).map {|w| w.to_hash}
        end

        def supported_locale
          case locale
          # English
          when /en-UK/ then "en-UK"
          when /en/ then "en"
          # Spanish
          when /es-MX/ then "es-MEX"
          when /es-ES/ then "es"
          when /es/ then "es"
          # German
          when /de/ then "de"
          # French
          when /fr/ then "fr"
          # Italian
          when /it/ then "it"
          # Dutch
          when /nl/ then "nl"
          else
            raise UnsupportedLocale, "Unsupported language"
          end
        end
      end
    end
  end
end
