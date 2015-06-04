module CPW
  module Worker
    class Base
      include ::Shoryuken::Worker
      include CPW::Client::Resources

      attr_reader :logger
      attr_accessor :ingest, :body, :sqs_message, :test

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
          index = CPW::Client::Resources::Ingest::workflow.index(stage_name.to_sym)
          CPW::Client::Resources::Ingest::workflow[index + 1].try(:to_s) if index
        end

        def next_stage_class
          class_for(next_stage_name) if next_stage_name
        end

        def previous_stage_name
          index = CPW::Client::Resources::Ingest::workflow.index(stage_name.to_sym)
          CPW::Client::Resources::Ingest::workflow[index - 1].try(:to_s) if index
        end

        def previous_stage_class
          class_for(previous_stage_name) if previous_stage_name
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
        # E.g. CPW::Worker::Archive.perform_test({"ingest_id" => 46})
        def perform_test(body)
          sqs_message          = SQSTestMessage.new("dev")
          worker_instance      = self.new
          worker_instance.test = true

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

      def test?
        !!@test
      end

      def workflow?
        !!(body && body['workflow'])
      end

      def before_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#before_perform: #{body.inspect}\n"
        self.sqs_message, self.body = sqs_message, body
      end

      def after_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#after_perform: #{body.inspect}\n"

        sqs_message.delete unless should_retry?

        logger.info("+++ #{self.class.name}#workflow? -> #{workflow?}")
        logger.info("+++ #{self.class.name}#has_next_stage? -> #{has_next_stage?}")
        logger.info("+++ #{self.class.name}#should_retry? -> #{should_retry?}")

        # Launch next stage, if part of a workflow
        if workflow? && has_next_stage? && !should_retry? && !terminate?
          new_body = body.merge({"workflow" => workflow?})
          logger.info "+++ #{next_stage_class.name}#perform_async: #{new_body.inspect}\n"
          next_stage_class.perform_async(new_body) unless test?
        end
      end

      def lock
        logger.info "+++ #{self.class.name}#lock #{body.inspect}"
        load_ingest
        if block_given?
          begin
            if can_lock?
              update_ingest({stage: stage_name, busy: true})
              if can_stage?
                @can_perform = true
                yield
              end
            else
              @should_retry = true
            end
          rescue => ex
            @should_retry = true
            raise ex
          ensure
            unlock if busy?
          end
        else
          raise "Requires a block"
        end
      end

      protected

      def can_perform?
        !!@can_perform
      end

      def should_retry?
        !!@should_retry
      end

      def busy?
        @ingest.try(:id) && !!@ingest.busy
      end

      def terminate?
        @ingest.try(:id) && !!@ingest.terminate
      end

      def can_lock?
        !busy? && !terminate?
      end

      def can_stage?
        if workflow?
          current_stage_position  = Ingest::STAGES[stage_name.to_sym].to_i
          previous_stage_position = previous_stage_name ? Ingest::STAGES[previous_stage_name.to_sym].to_i : 0

          logger.info("+++ #{self.class.name}@stage -> #{@ingest.stage}")
          logger.info("+++ #{self.class.name}@ingest.state_started? -> #{@ingest.state_started?}")
          logger.info("+++ #{self.class.name}@current_stage_position -> #{current_stage_position}")
          logger.info("+++ #{self.class.name}@previous_stage_position -> #{previous_stage_position}")

          ((@ingest.stage && @ingest.state_started?) || @ingest.stage == "start") &&
            current_stage_position > previous_stage_position
        else
          true
        end
      end

      def finished_progress
        self.class.finished_progress.to_i
      end

      def unlock
        attributes = {busy: false}
        if finished_progress > 0 && can_perform?
          attributes.merge!(progress: finished_progress)
        end
        update_ingest(attributes)
        logger.info "+++ #{self.class.name}#unlock #{attributes.inspect}"
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
        @ingest = Ingest.secure_find(body['ingest_id']) if body && body['ingest_id']
      end

      def update_ingest(attributes = {})
        logger.info "+++ #{self.class.name}#update_ingest #{attributes.inspect}"
        @previous_stage_name = @ingest.stage
        @ingest = Ingest.secure_update(@ingest.id, attributes)
      end

      def previous_stage_name
        @previous_stage_name
      end

      def terminate?
        @terminate || (@ingest && @ingest.terminate)
      end
    end  # Base
  end  # Worker
end  # CPW