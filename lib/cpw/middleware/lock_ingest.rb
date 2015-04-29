module CPW
  module Middleware
    class LockIngest

      def call(worker_instance, queue, sqs_message, body)
        worker_instance.before_perform(sqs_message, body)
        worker_instance.lock do
          yield
        end
        worker_instance.after_perform(sqs_message, body)
      end

    end
  end
end