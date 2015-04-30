module CPW
  module Worker
    class Archive < Worker::Base
      extend Worker::Helper

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")
      end

    end
  end
end