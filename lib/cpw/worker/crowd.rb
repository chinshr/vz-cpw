module CPW
  module Worker
    class Crowd < Worker::Base
      extend Worker::Helper

      SOURCE_CHUNK_SCORE_THRESHOLD    = 0.8
      REFERENCE_CHUNK_SCORE_THRESHOLD = 0.95

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        # Chunks to be crowd sourced
        source_chunks = Ingest::Chunk.where({ingest_id: @ingest.id,
          any_of_ingest_iterations: @ingest.iteration,
          score_lt: SOURCE_CHUNK_SCORE_THRESHOLD,
          any_of_types: "pocketsphinx"
        })

        # Go through each of them and find a reference chunk
        source_chunks.each do |source_chunk|
          reference_chunks = Ingest::Chunk.where({
            none_of_ingest_ids: [@ingest.id],
            none_of_types: ["mechanical_turk"],
            score_gteq: REFERENCE_CHUNK_SCORE_THRESHOLD,
            duration_lteq: source_chunk.duration.to_f + 3.0,
            any_of_locales: locale_language(source_chunk.locale),
            sort_order: [:random], limit: 1
          })

          merged_chunk = merge(source_chunk, reference_chunks)
        end
      end

      protected

      def merge(source_chunk, reference_chunks)
        # * download mp3 files
        # * merge mp3 files
        # * generate waveform json
        # * upload merged mp3
        # * upload merged waveform json
        # * create "ephemeral" chunk
        logger.info("Source Chunk: #{source_chunk.inspect}")
        logger.info("Reference Chunk: #{reference_chunks.to_a.inspect}")
      end

      private

      def locale_language(locale)
        locale.to_s.match(/^(\w{2})/) ? $1.to_s : nil
      end
    end
  end
end