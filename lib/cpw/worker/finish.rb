module CPW
  module Worker
    class Finish < Worker::Base
      include Worker::Helper

      self.finished_progress = 100

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        update_ingest({status: Ingest::STATE_FINISHED})
      end

    end
  end
end