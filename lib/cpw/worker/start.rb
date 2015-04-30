module CPW
  module Worker
    class Start < Worker::Base
      extend Worker::Helper
      self.finished_progress = 1

      shoryuken_options queue: -> { queue_name },
          auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        update_ingest({status: Ingest::STATE_STARTED})
      end

    end
  end
end