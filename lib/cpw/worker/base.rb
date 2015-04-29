module CPW
  module Worker
    class Base
      include CPW::Client::Resources

      attr_reader :sqs, :queue, :logger, :message, :ingest

      def initialize
        @terminate = false
        @logger    = CPW::logger
        @sqs       = AWS::SQS.new
        @queue     = sqs.queues.named(queue_name)
        @ingest_id = nil

        # $DEBUG = true
        Thread.abort_on_exception = true
      end

      class << self
        attr_accessor :downstream_worker_class_name

        def perform_async(*args)
          logger.info "Calling worker #{self.name}"
          self.new.queue.send_message({ingest_id: ingest_id}.to_json)
        end
      end

      def run
        at_exit do
          stop "at_exit"
        end

        logger.info "Listening on queue #{queue_name}"
        queue.poll(wait_time_seconds: 10) do |message|
          self.message = JSON.parse(received_message.body)
          lock do
            before_perform(message)
            perform(message)
            after_perform(message)
          end
          break if terminate?
          invoke_next
        end
      ensure
        unlock
      end

      def perform(*args)
        raise "Implement in subclass"
      end

      def before_perform(message)
        logger.info "Processing #{self.class.name}#message #{message.inspect}\n"
      end

      def after_perform(message)
        logger.info "Finished processing #{self.class.name}#message #{message.inspect}\n"
      end

      def stop(signal = nil)
        @terminate = true
        logger.info "Stopping poll loop for #{queue_name}. (#{signal})"
      end

      def ingest_id
        @ingest.id if @ingest
      end

      protected

      def lock
        logger.info "locking #{queue_name}"
        load_ingest
        if block_given?
          begin
            if can_lock?
              ingest.update_attributes(stage: stage_name, busy: true) if ingest
              yield
            end
          ensure
            unlock
          end
        else
          ingest.update_attributes(stage: stage_name, busy: true) if can_lock?
        end
      end

      def can_lock?
        ingest && !ingest.terminate
      end

      def unlock
        logger.info "unlocking #{queue_name}"
        ingest.update_attributes(busy: false) if ingest
      end

      def invoke_next
        if self.class.downstream_worker_class_name && ingest_id
          worker_class = self.class.downstream_worker_class_name.classify
          logger.info "Calling downstream worker #{worker_class.name}"
          worker_class.new.queue.send_message({ingest_id: ingest_id}.to_json)
        end
      end

      def stage_name
        self.class.name.split("::").last.underscore
      end

      def queue_name
        name = ENV['QUEUE_NAME'].dup
        name.gsub!(/%{stage}/i, stage_name)
        name.gsub!(/%{environment}/i, ENV.fetch('ENVIRONMENT', 'development'))
        name.upcase
      end

      def load_ingest
        @ingest = Ingest.find(message['ingest_id']) if message && message['ingest_id']
      end

      def terminate?
        @terminate || (@ingest && @ingest.terminate)
      end
    end  # Base
  end  # Worker
end  # CPW