require "srt"

module CPW
  module Speech
    module Engines
      class SubtitleEngine < SpeechEngine
        attr_accessor :format, :default_chunk_score, :response

        def initialize(media_file_or_url, options = {})
          super media_file_or_url, options
          self.format              = options[:format]
          self.default_chunk_score = options[:default_chunk_score]
        end

        def split(splitter)
          chunks   = []
          subtitle_file = SRT::File.parse(File.new(splitter.original_file))
          subtitle_file.lines.each do |line|
            if line.sequence && line.sequence > 0
              chunks << AudioChunk.new(splitter, decode_start_time(line),
                decode_duration(line), {position: line.sequence, raw_response: build_raw_response(line)})
            end
          end
          chunks
        end

        protected

        def convert(chunk, options = {})
          result = {'status' => (chunk.status = CPW::Speech::STATUS_PROCESSING)}
          if chunk.raw_response.present?  # from splitter
            parse(chunk, chunk.raw_response, result)
            logger.info "chunk #{chunk.position} processed: #{result.inspect}" if self.verbose
          else
            result['status'] = chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
          end
        ensure
          chunk.processed_stages << :convert
          chunk.normalized_response.merge!(result)
          chunk.clean
          return result
        end

        def parse(chunk, raw_data, result = {})
          data = chunk.raw_response = raw_data
          result['position']        = chunk.position
          result['id']              = chunk.id

          if data.key?('text')
            result['hypotheses']    = [{'utterance' => data['text'], 'confidence' => default_chunk_score}]
            result['status']        = chunk.status = CPW::Speech::STATUS_PROCESSED
            chunk.best_text         = data['text']
            chunk.best_score        = default_chunk_score

            logger.info "result: #{result.inspect}" if self.verbose
          else
            chunk.status = CPW::Speech::STATUS_PROCESSING_ERROR
          end
          result
        end

        private

        def decode_start_time(line)
          line.start_time
        end

        def decode_end_time(line)
          line.end_time
        end

        def decode_duration(line)
          start_time = decode_start_time(line)
          end_time   = decode_end_time(line)
          if (start_time && end_time)
            end_time - start_time
          end
        end

        def build_raw_response(subtitle_line)
          response = {}
          response['text']       = subtitle_line.text.join(" ")
          response['start_time'] = subtitle_line.start_time
          response['end_time']   = subtitle_line.end_time
          response['sequence']   = subtitle_line.sequence
          response['error']      = subtitle_line.error if subtitle_line.error
          response['display_coordinates'] = subtitle_line.display_coordinates if subtitle_line.try(:display_coordinates)
          response
        end

      end
    end
  end
end
