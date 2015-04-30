module CPW
  module Worker
    class Base
      include ::Shoryuken::Worker
      include CPW::Client::Resources

      attr_reader :logger
      attr_accessor :ingest, :body, :sqs_message

      class << self
        attr_accessor :finished_progress

        def stage_name
          name.split("::").last.underscore
        end

        def queue_name
          name = ENV['QUEUE_NAME'].dup
          name.gsub!(/%{stage}/i, stage_name)
          name.gsub!(/%{environment}/i, ENV.fetch('ENVIRONMENT', 'development'))
          name.upcase
        end

        def next_stage_name
          index = CPW::Client::Resources::Ingest::WORKFLOW.index(stage_name.to_sym)
          CPW::Client::Resources::Ingest::WORKFLOW[index + 1].try(:to_s) if index
        end

        def next_stage_class
          class_for(next_stage_name) if next_stage_name
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

        SQSTestMessage = Struct.new(:name) do; def delete; end; end

        # Note: For running workers manually.
        # E.g. CPW::Worker::Archive.test_run({"ingest_id" => 46})
        def test_run(body)
          sqs_message     = SQSTestMessage.new("dev")
          worker_instance = self.new
          worker_instance.before_perform(sqs_message, body)
          worker_instance.lock do
            worker_instance.perform(sqs_message, body)
          end
          worker_instance.after_perform(sqs_message, body)
        end

        private

        def class_for(file_name_or_stage_name)
          name = File.basename(file_name_or_stage_name, ".rb")
          ("CPW::Worker::" + name[0].upcase + name[1...name.length]).constantize
        end
      end

      self.finished_progress = 0

      def initialize
        @terminate = false
        @logger    = CPW::logger
      end

      def before_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#before_perform: #{body.inspect}\n"
        self.sqs_message, self.body = sqs_message, body
      end

      def after_perform(sqs_message, body)
        sqs_message.delete if sqs_message.respond_to?(:delete) unless should_retry?

        # Launch next stage, if part of a workflow
        if workflow? && has_next_stage?
          message = body.merge({"workflow" => workflow?})
          logger.info "+++ #{next_stage_class.name}#perform_async: #{message.inspect}\n"
          next_stage_class.perform_async(message)
        end

        logger.info "+++ #{self.class.name}#after_perform: #{body.inspect}\n"
      end

      def workflow?
        !!(body && body['workflow'])
      end

      def should_retry?
        false
      end

      def lock
        logger.info "+++ #{self.class.name}#lock #{body.inspect}"
        load_ingest
        if block_given?
          begin
            if can_lock?
              Ingest.update(@ingest.id, {stage: stage_name, busy: true})
              yield
            end
          ensure
            unlock
          end
        else
          raise "Requires a block"
        end
      end

      protected

      def can_lock?
        @ingest && (!@ingest.busy || !@ingest.terminate) &&
          ((@ingest.stage && @ingest.state_started?) || !@ingest.stage) &&
          Ingest::STAGES[stage_name.to_sym].to_i > Ingest::STAGES[@ingest.stage.to_sym].to_i
      end

      def finished_progress
        self.class.finished_progress.to_i
      end

      def unlock
        attributes = {busy: false}
        attributes.merge!(progress: finished_progress) if finished_progress > 0
        Ingest.update(@ingest.id, attributes) if @ingest
        logger.info "+++ #{self.class.name}#unlock #{queue_name}"
      end

      def stage_name
        self.class.stage_name
      end

      def next_stage_name
        self.class.next_stage_name
      end

      def has_next_stage?
        !!self.class.next_stage_name
      end

      def next_stage_class
        self.class.next_stage_class
      end

      def queue_name
        self.class.queue_name
      end

      def load_ingest
        logger.info "+++ #{self.class.name}#load_ingest #{body.inspect}"
        @ingest = Ingest.find(body['ingest_id']) if body && body['ingest_id'] && !@ingest
      end

      def terminate?
        @terminate || (@ingest && @ingest.terminate)
      end
    end  # Base
  end  # Worker
end  # CPW