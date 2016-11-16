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
        if engine && engine.respond_to?(:split) && split_method == :auto
          engine.split(self)
        else
          case split_method
          when :diarize then split_with_diarize
          else
            split_with_basic
          end
        end
      end

      protected

      def split_with_basic
        result      = []
        chunk_id    = 1
        full_chunks = (self.duration.to_f / self.chunk_duration).to_i
        last_chunk  = ((self.duration.to_f % self.chunk_duration) * 100).round / 100.0
        logger.info "generate: #{full_chunks} chunks of #{chunk_duration} seconds, last: #{last_chunk} seconds" if self.verbose

        (full_chunks - 1).times do |index|
          if index > 0
            result << AudioChunk.new(self, index * self.chunk_duration, self.chunk_duration, {id: chunk_id})
          else
            off = (index * self.chunk_duration) - (self.chunk_duration / 2)
            off = 0 if off < 0
            result << AudioChunk.new(self, off, self.chunk_duration, {id: chunk_id})
          end
          chunk_id += 1
        end

        if result.empty?
          result << AudioChunk.copy(self, chunk_id)
        else
          result << AudioChunk.new(self, result.last.offset.to_i + result.last.duration.to_i, self.chunk_duration + last_chunk, {id: chunk_id})
        end
        logger.info "Chunk (id=#{chunk_id}) count: #{result.size}" if self.verbose
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
        diarize_audio.segments.each_with_index do |segment, index|
          chunks << AudioChunk.new(self, segment.start, segment.duration,
            {id: index + 1, bandwidth: segment.bandwidth, speaker: segment.speaker})
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
    end
  end
end
