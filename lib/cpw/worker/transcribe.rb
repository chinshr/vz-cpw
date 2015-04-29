module CPW
  module Worker
    class Transcribe < Worker::Base
      extend Worker::Helper

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
      end
    end
  end
end