module CPW
  class Worker
    attr_reader :sqs, :queue, :logger
    attr_accessor :ingest_id

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
    end

    def run
      at_exit do
        stop "at_exit"
      end

      logger.info "Listening on queue #{queue_name}"
      queue.poll(wait_time_seconds: 10) do |message|
        message = JSON.parse(received_message.body)
        lock
        logger.info "Process #{self.class.name}, message body #{message.inspect}\n"
        process(message)
        unlock
        invoke_next
        break if @terminate
      end
    ensure
      unlock
    end

    def process(message)
      # Implement in subclass
    end

    def stop(signal = nil)
      @terminate = true
      logger.info "Stopping poll loop for #{queue_name}. (#{signal})"
    end

    protected

    def lock
      logger.info "lock #{queue_name}"
    end

    def unlock
      logger.info "unlock #{queue_name}"
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
  end
end