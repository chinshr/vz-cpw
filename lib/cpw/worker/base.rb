module CPW
  module Worker
    class ResourceLockError < Exception; end
    class ResourceLoadError < Exception; end

    class Base
      include ::Shoryuken::Worker

      attr_accessor :logger, :ingest, :body, :sqs_message, :test

      class << self
        attr_accessor :finished_progress

        # E.g. Ingest::MediaIngest::ArchiveWorker -> 'archive'
        def stage_name
          result = name.split("::").last.underscore
          result.gsub!(/_worker$/i, '')
          result
        end

        # E.g. Ingest::MediaIngest::ArchiveWorker -> :archive_stage
        def stage
          "#{stage_name}_stage".to_sym if stage_name
        end

        def queue_name
          tokens = self.name.split("::")
          tokens = tokens.map {|t| t.underscore.gsub(/_worker/, "").upcase }
          "#{tokens.join('_')}_#{CPW.env.upcase}_QUEUE"
        end

        def register_workers
          CPW::Worker::Base.subclasses.each do |worker_class|
            Shoryuken.register_worker(worker_class.queue_name, worker_class)
          end
        end

        SQSTestMessage = Struct.new(:name) do; def delete; end; end

        # Note: For running workers manually.
        # E.g. Ingest::MediaIngest::HarvestWorker.perform_test({"ingest_id" => 81})
        def perform_test(body)
          sqs_message          = SQSTestMessage.new(CPW.env)
          worker_instance      = self.new
          worker_instance.test = true

          worker_instance.before_perform(sqs_message, body)
          worker_instance.lock do
            worker_instance.perform(sqs_message, body)
          end
          worker_instance.after_perform(sqs_message, body)
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

      def workflow_stage?
        !!(ingest && ingest.stages.include?(self.class.stage))
      end

      def force?
        !!(body && body['force'])
      end

      def ingest_id
        body.try(:[], 'ingest_id')
      end

      def before_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#before_perform: #{body.inspect}\n"
        self.sqs_message, self.body = sqs_message, body
      end

      def after_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#after_perform: #{body.inspect}\n"

        sqs_message.delete if should_not_retry? || terminate?

        logger.info("+++ #{self.class.name}#workflow? -> #{workflow?}")
        logger.info("+++ #{self.class.name}#has_next_stage? -> #{has_next_stage?}")
        logger.info("+++ #{self.class.name}#should_retry? -> #{should_retry?}")

        # Sprinkle a bit of joy...
        GC.start

        # Launch next stage, if part of a workflow
        if workflow? && has_next_stage? && finished_perform? && !terminate?
          attributes = {trigger: "#{self.class.stage}"}
          logger.info "+++ #{self.class.name}: trigger next stage for Ingest id=#{ingest.id} update_attributes(#{attributes.inspect})\n"
          update_ingest(attributes)
        end
      end

      def lock
        logger.info "+++ #{self.class.name}#lock #{body.inspect}"
        if block_given?
          begin
            lock_ingest!
            @can_perform = true
            yield
            @finished_perform = true
          rescue ResourceLoadError => ex
            logger.info "+++ #{self.class.name}#lock load error: #{ex.message}."
          rescue ResourceLockError => ex
            logger.info "+++ #{self.class.name}#lock lock error: #{ex.message}."
          rescue => ex
            logger.info "+++ #{self.class.name}#lock worker exception caught ingest id=#{ingest.id}, retrying."
            @should_retry      = !terminate?
            @has_perform_error = true
            @saved_exception   = ex
            raise ex
          ensure
            unlock_ingest!
          end
        else
          raise "no block given"
        end
      end

      def terminate!
        @terminate = true
      end

      def increment_progress!(increment = 1, max_progress = finished_progress)
        progress = ingest.progress
        progress += increment
        @ingest = Ingest.secure_update(ingest.id, progress: progress) if progress < max_progress
      end

      protected

      def lock_ingest!(attributes = {})
        load_ingest

        attributes = attributes.merge({busy: true}).reject {|k,v| v.nil?}
        if workflow? && workflow_stage?
          attributes.merge!({status: Ingest::STATE_STARTED})
          attributes.merge!({event: "forward_to_#{self.class.stage}"})
        end

        logger.info "+++ #{self.class.name}#lock_ingest! id=#{ingest_id}, #{attributes.inspect}"

        @ingest = update_ingest(attributes)
        raise ResourceLockError, "Cannot lock ingest (id=#{ingest_id}): #{ingest.errors.inspect}" unless ingest.errors.empty?
      end

      def unlock_ingest!(attributes = {})
        attributes = attributes.merge({busy: false}).reject {|k,v| v.nil?}

        # process stored exception context
        if ingest.present? && @saved_exception
          new_messages = ingest.messages || {}
          new_messages[self.class.stage_name] ||= {}
          new_messages[self.class.stage_name]["message"] = @saved_exception.message
          if @saved_exception.backtrace
            new_messages[self.class.stage_name]["backtrace"] = @saved_exception.backtrace
          end
          attributes.merge!({messages: new_messages})
        end

        # stop workflow when exception was raised in perform block
        if workflow? && has_perform_error?
          attributes.merge!({status: Ingest::STATE_STOPPING})
        end

        # update ingest
        logger.info "+++ #{self.class.name}#unlock_ingest! #{attributes.inspect}"
        update_ingest(attributes)
      end

      def has_next_stage?
        !!(workflow_stage? && ingest && !!ingest.next_stage)
      end

      def queue_name
        self.class.queue_name
      end

      private

      def busy?
        @ingest.try(:id) && !!@ingest.busy
      end

      def finished_progress
        self.class.finished_progress.to_i
      end

      def load_ingest
        logger.info "+++ #{self.class.name}#load_ingest #{body.inspect}"

        ingest_id = body.try(:[], 'ingest_id')
        raise ResourceLoadError, "Cannot find ingest_id in message body" unless ingest_id

        @ingest = Ingest.secure_find(ingest_id)
        raise ResourceLoadError, "Cannot load ingest (id=#{ingest_id}): ingest not found" unless @ingest.present?

        @ingest
      end

      def update_ingest(attributes = {})
        logger.info "+++ #{self.class.name}#update_ingest id=#{ingest_id}, #{attributes.inspect}"
        @ingest = Ingest.secure_update(ingest_id, attributes)
      end

      def terminate?
        @terminate || (ingest.try(:id) && ingest.terminate)
      end

      def can_perform?
        !!@can_perform
      end

      def finished_perform?
        !!@finished_perform
      end

      def should_retry?
        !!@should_retry
      end

      def should_not_retry?
        !should_retry?
      end

      def has_perform_error?
        !!@has_perform_error
      end

    end  # Base
  end  # Worker
end  # CPW