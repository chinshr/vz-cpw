module CPW
  module Worker
    class Stop < Worker::Base
      extend Worker::Helper

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        update_ingest({status: Ingest::STATE_STOPPED})

        sqs_message.delete
      end

    end
  end
end