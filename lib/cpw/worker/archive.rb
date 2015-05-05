module CPW
  module Worker
    class Archive < Worker::Base
      include Worker::Helper

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")
      end

    end
  end
end