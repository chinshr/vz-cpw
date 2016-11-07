module CPW
  module Logger
    class WorkerLogDevice
      attr_reader :worker

      def initialize(worker)
        @worker = worker
      end

      def write(message)
        @worker.send(:push_logger_message, message)
      rescue Exception => ignored
        warn("log writing failed. #{ignored}")
      end

      def close
        # nop
      end
    end
  end
end
