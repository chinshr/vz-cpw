module CPW
  module Worker
    class Finish < Worker::Base
      extend Worker::Helper
      self.finished_progress = 100

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")
      end

    end
  end
end