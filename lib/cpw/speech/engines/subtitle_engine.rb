require "srt"

module CPW
  module Speech
    module Engines
      class SubtitleEngine < Base
        attr_accessor :format
        attr_accessor :default_chunk_score

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
                decode_duration(line), {id: line.sequence, response: build_response(line)})
            end
          end
          chunks
        end

        def to_json(options = {})
          perform(options)
          return {"chunks" => chunks.map {|ch| ch.response }}
        end

        protected

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
            chunk.best_score        = default_chunk_score
            self.segments           += 1
            logger.info "text: #{result['text']}" if self.verbose
          else
            chunk.status = AudioChunk::STATUS_TRANSCRIPTION_ERROR
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

        def build_response(subtitle_line)
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
