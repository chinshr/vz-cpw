module CPW
  module Speech

    class AudioSplitter
      attr_accessor :original_file, :size, :duration, :chunks, :verbose,
        :engine, :logger, :basefolder

      def initialize(file, options = {})
        self.original_file = file
        self.duration      = AudioInspector.new(file).duration
        self.size          = options.key?(:chunk_size) ? options[:chunk_size].to_i : 5
        self.chunks        = []
        self.verbose       = !!options[:verbose] if options.key?(:verbose)
        self.engine        = options[:engine]
        self.basefolder    = options[:basefolder]
        self.logger        = CPW::logger
      end

      def base_file_type
        engine ? engine.base_file_type : :flac
      end

      def source_file_type
        engine ? engine.source_file_type : nil
      end

      def split
        if engine && engine.respond_to?(:split)
          self.chunks = engine.split(self)
        else
          # compute the total number of chunks
          chunk_id    = 1
          full_chunks = (self.duration.to_f / size).to_i
          last_chunk  = ((self.duration.to_f % size) * 100).round / 100.0
          logger.info "generate: #{full_chunks} chunks of #{size} seconds, last: #{last_chunk} seconds" if self.verbose

          (full_chunks - 1).times do |index|
            if index > 0
              chunks << AudioChunk.new(self, index * self.size, self.size, {id: chunk_id})
            else
              off = (index * self.size) - (self.size / 2)
              off = 0 if off < 0
              chunks << AudioChunk.new(self, off, self.size, {id: chunk_id})
            end
            chunk_id += 1
          end

          if chunks.empty?
            chunks << AudioChunk.copy(self, chunk_id)
          else
            chunks << AudioChunk.new(self, chunks.last.offset.to_i + chunks.last.duration.to_i, self.size + last_chunk, {id: chunk_id})
          end
          logger.info "Chunk (id=#{chunk_id}) count: #{chunks.size}" if self.verbose
        end
        chunks
      end
    end

  end
end