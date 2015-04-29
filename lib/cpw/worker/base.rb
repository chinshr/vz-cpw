module CPW
  module Worker
    class Base
      include ::Shoryuken::Worker
      include CPW::Client::Resources

      attr_reader :logger
      attr_accessor :ingest, :body, :sqs_message

      class << self
        def stage_name
          name.split("::").last.underscore
        end

        def queue_name
          name = ENV['QUEUE_NAME'].dup
          name.gsub!(/%{stage}/i, stage_name)
          name.gsub!(/%{environment}/i, ENV.fetch('ENVIRONMENT', 'development'))
          name.upcase
        end

        def register_cpw_workers
          # Shoryuken.register_worker("HARVEST_DEVELOPMENT_QUEUE", CPW::Worker::Harvest)
          # Shoryuken.register_worker("TRANSCODE_DEVELOPMENT_QUEUE", CPW::Worker::Transcode)
          # Shoryuken.register_worker("TRANSRIBE_DEVELOPMENT_QUEUE", CPW::Worker::Transcribe)
          # Shoryuken.register_worker("ARCHIVE_DEVELOPMENT_QUEUE", CPW::Worker::Archive)
          Dir[File.dirname(__FILE__) + "/*.rb"].each do |file|
            unless ["base", "helper"].include?(File.basename(file, ".rb"))
              Shoryuken.register_worker(class_for(file).queue_name, class_for(file))
            end
          end
        end

        private

        def class_for(file_name)
          name = File.basename(file_name, ".rb")
          ("CPW::Worker::" + name[0].upcase + name[1...name.length]).constantize
        end
      end

      def initialize
        @terminate = false
        @logger    = CPW::logger
      end

      def before_perform(sqs_message, body)
        logger.info "#{self.class.name}#before_perform: #{body.inspect}\n"
        self.sqs_message, self.body = sqs_message, body
      end

      def after_perform(sqs_message, body)
        sqs_message.delete if sqs_message.respond_to?(:delete) unless should_retry?
        logger.info "#{self.class.name}#after_perform: #{body.inspect}\n"
      end

      def should_retry?
        false
      end

      def lock
        logger.info "+++ locking #{queue_name}"
        load_ingest

        if block_given?
          begin
            if can_lock?
              @ingest.update_attributes(stage: stage_name, busy: true) if @ingest
              yield
            end
          ensure
            unlock
          end
        else
          ingest.update_attributes(stage: stage_name, busy: true) if can_lock?
        end
      end

      protected

      def can_lock?
        ingest && !ingest.terminate
      end

      def unlock
        logger.info "unlocking #{queue_name}"
        ingest.update_attributes(busy: false) if ingest
      end

      def stage_name
        self.class.stage_name
      end

      def queue_name
        self.class.queue_name
      end

      def load_ingest
        logger.info "+++ Worker::Base#load_ingest #{body.inspect}"
        @ingest = Ingest.find(body['ingest_id']) if body && body['ingest_id'] && !@ingest
      end

      def terminate?
        @terminate || (@ingest && @ingest.terminate)
      end
    end  # Base
  end  # Worker
end  # CPW