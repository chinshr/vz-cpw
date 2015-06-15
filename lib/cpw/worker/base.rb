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
          name.gsub!(/%{env}/i, ENV.fetch('CPW_ENV', 'development'))
          name.upcase
        end

        def register_cpw_workers
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

        # class_for('finish') -> CPW::Worker::Finish
        def class_for(file_name_or_stage_name)
          name = File.basename(file_name_or_stage_name.to_s, ".rb")
          if name.length > 0
            ("CPW::Worker::" + name.classify).constantize
          end
        end
      end  # class methods

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

      def force?
        !!(body && body['force'])
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
        if workflow? && has_next_stage? && !should_retry? && !terminate? && !test?
          logger.info "+++ #{ingest.next_stage_worker_class.name}#perform_async: #{body.inspect}\n"
          ingest.next_stage_worker_class.perform_async(body)
        end
      end

      def lock
        logger.info "+++ #{self.class.name}#lock #{body.inspect}"
        load_ingest
        if block_given?
          begin
            if can_lock?
              @saved_stage_name = ingest.current_stage_name
              lock!
              if can_stage? @saved_stage_name
                @can_perform = true
                yield
              end
            else
              logger.info "+++ #{self.class.name}#can_lock? -> false = unable to lock ingest id=#{ingest.id}, retrying."
              @should_retry = true
            end
          rescue => ex
            logger.info "+++ #{self.class.name}#lock exception caught performing ingest id=#{ingest.id}, retrying."
            @should_retry = true
            @has_perform_error = true
            raise ex
          ensure
            unlock! if busy?
          end
        else
          raise "no block given"
        end
      end

      protected

      def can_perform?
        !!@can_perform
      end

      def should_retry?
        !!@should_retry
      end

      def has_perform_error?
        !!@has_perform_error
      end

      def busy?
        @ingest.try(:id) && !!@ingest.busy
      end

      def terminate?
        @ingest.try(:id) && !!@ingest.terminate
      end

      def can_lock?
        force? ? true : (!busy? && !terminate?)
      end

      def can_stage?(saved_stage_name)
        if workflow?
          current_stage_position = ingest.workflow_stage_names.index(self.class.stage_name)
          current_finished_stage_progress = self.class.finished_progress.to_i
          saved_stage_position   = saved_stage_name ? ingest.workflow_stage_names.index(saved_stage_name) : -1

    #byebug

          # Can perform/stage if:
          # (1) We are at the beginning of the workflow (stage `start`)
          # (2) Or, the workflow has started and staged
          # (3) And, current stage position greater equal saved stage position

          ((ingest.state_starting? && self.class.stage_name == "start") ||
           (ingest.state_started? && !!ingest.current_stage_name)) &&

          current_stage_position >= saved_stage_position &&
            ingest.progress < current_finished_stage_progress
        else
          true
        end
      end

      def finished_progress
        self.class.finished_progress.to_i
      end

      def lock!(attributes = {})
        attributes = attributes.merge({busy: true}).reject {|k,v| v.nil?}
        attributes.merge!({stage: self.class.stage_name}) if workflow?
        logger.info "+++ #{self.class.name}#lock! #{attributes.inspect}"
        update_ingest(attributes)
      end

      def unlock!(attributes = {})
        attributes = attributes.merge({busy: false}).reject {|k,v| v.nil?}
        if finished_progress > 0 && can_perform? && !has_perform_error?
          attributes.merge!({progress: finished_progress})
        end
        logger.info "+++ #{self.class.name}#unlock! #{attributes.inspect}"
        update_ingest(attributes)
      end

      def has_next_stage?
        ingest && ingest.next_stage_name
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
        @previous_stage_name || @ingest.previous_stage_name
      end

      def terminate?
        @terminate || (@ingest && @ingest.terminate)
      end
    end  # Base
  end  # Worker
end  # CPW