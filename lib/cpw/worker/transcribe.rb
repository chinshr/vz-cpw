module CPW
  module Worker
    class Transcribe < Worker::Base
      extend Worker::Helper

      self.finished_progress = 99

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

#        Ingest::Chunk.create(ingest_id: @ingest.id, text: "test", offset: 0,
#          track_attributes: {s3_url: "track-1.url", s3_mp3_url: "track-1.128.mp3.url"})
      end
    end
  end
end