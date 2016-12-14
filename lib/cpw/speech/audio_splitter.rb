module CPW
  module Speech

    class AudioSplitter
      attr_accessor :original_file, :chunk_duration, :duration, :chunks, :verbose,
        :engine, :logger, :basefolder, :split_method, :split_options, :diarize_audio

      def initialize(file_name, options = {})
        self.original_file  = file_name
        self.duration       = AudioInspector.new(file_name).duration
        self.chunks         = []
        assign_options(options)
      end

      def base_file_type
        engine ? engine.base_file_type : :flac
      end

      def source_file_type
        engine ? engine.source_file_type : nil
      end

      def split(options = {})
        assign_options(options)
        case split_method
        when :diarize then split_with_diarize
        when :basic then split_with_basic
        when :auto
          if engine && engine.respond_to?(:split)
            engine.split(self)
          else
            if engine
              raise InvalidSplitMethod, "unsupported #split_method `#{split_method}` in `#{engine.class.inspect}` engine."
            else
              raise InvalidSplitMethod, "unsupported #split_method `#{split_method}`."
            end
          end
        else
          raise InvalidSplitMethod, "split_method `#{split_method}` not supported."
        end
      end

      protected

      def split_with_basic
        result, position = [], 1
        full_chunks = (self.duration.to_f / self.chunk_duration).to_i
        last_chunk  = ((self.duration.to_f % self.chunk_duration) * 100).round / 100.0
        logger.info "generate: #{full_chunks} chunks of #{chunk_duration} seconds, last: #{last_chunk} seconds" if self.verbose

        (full_chunks - 1).times do |index|
          if index > 0
            result << AudioChunk.new(self, index * self.chunk_duration, self.chunk_duration, {position: position})
          else
            off = (index * self.chunk_duration) - (self.chunk_duration / 2)
            off = 0 if off < 0
            result << AudioChunk.new(self, off, self.chunk_duration, {position: position})
          end
          position += 1
        end

        if result.empty?
          result << AudioChunk.copy(self, position)
        else
          result << AudioChunk.new(self, result.last.offset.to_i + result.last.duration.to_i, self.chunk_duration + last_chunk, {position: position})
        end
        logger.info "Chunk (position=#{position}) count: #{result.size}" if self.verbose
        result
      end

      def split_with_diarize
        chunks = []
        file_uri = URI.join('file:///', original_file)

        if split_options[:mode] == :druby
          host = split_options[:host] || "localhost"
          port = split_options[:port] || 9999
          server_uri = "druby://#{host}:#{port}"
          DRb.start_service
          server = DRbObject.new_with_uri(server_uri)
          self.diarize_audio = server.build_audio(file_uri)
        else
          self.diarize_audio = Diarize::Audio.new(file_uri)
        end

        diarize_audio.analyze!
        diarize_audio.segments.sort_by(&:start).each_with_index do |speaker_segment, index|
          chunk = AudioChunk.new(self, speaker_segment.start, speaker_segment.duration,
            {position: index + 1, speaker_segment: speaker_segment})
          normalize_speaker_segment_response(chunk)
          chunks.push(chunk)
        end
        chunks
      end

      private

      def assign_options(options = {})
        self.chunk_duration  = options[:chunk_duration] || chunk_duration || 5
        self.verbose         = options.key?(:verbose) ? !!options[:verbose] : !!verbose
        self.engine          = options[:engine] || engine
        self.basefolder      = options[:basefolder] || basefolder
        self.split_method    = options[:split_method] || split_method || :auto
        self.split_options   = options[:split_options] || split_options || {}
        self.logger          = options[:logger] || logger || CPW::logger
      end

      def normalize_speaker_segment_response(chunk)
        result, data = {}, chunk.speaker_segment._as_json

        result['start_time'] = data['start']
        result['duration']   = data['duration']
        result['end_time']   = data['start'] + data['duration'] if data['start'].is_a?(Float) && data['duration'].is_a?(Float)
        result['gender']     = data['gender']
        result['bandwidth']  = data['bandwidth']
        result['speaker_id'] = data['speaker_id']
        if data.has_key?('speaker')
          result['speaker_model_url'] = if data['speaker']['model']
            data['speaker']['model']
          else speaker_model_url(chunk)
            chunk.speaker_segment.speaker.model_uri = speaker_model_url(chunk)
          end
          result['speaker_mean_log_likelihood'] = data['speaker']['mean_log_likelihood']
          result['speaker_supervector_hash']    = data['speaker']['supervector_hash']
        end

        chunk.normalized_response.merge!({
          'status' => chunk.status,
          'speaker_segment' => result
        })
      end

      def speaker_model_url(chunk)
        if split_options.has_key?(:model_base_url)
          file_name = if split_options[:model_base_name]
            "#{split_options[:model_base_name]}-#{chunk.speaker_segment.speaker_id}.gmm"
          else
            "#{chunk.speaker_segment.speaker_id}.gmm"
          end
          URI.join(split_options[:model_base_url], file_name).to_s
        end
      end
    end
  end
end
