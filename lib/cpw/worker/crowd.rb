module CPW
  module Worker
    class Crowd < Worker::Base
      extend Worker::Helper

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        Ingest::Chunks.where(ingest_id: @ingest.id).where(score_lt: 0.8).where(any_of_types: "pocketsphinx")
      end

    end
  end
end