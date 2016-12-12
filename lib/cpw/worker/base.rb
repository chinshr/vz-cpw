module CPW
  module Worker
    class ResourceLockError < Exception; end
    class ResourceLoadError < Exception; end

    class Base
      include ::Shoryuken::Worker

      attr_accessor :logger, :ingest, :worker, :body, :sqs_message, :test,
        :runtime_error, :perform_error, :can_perform, :finished_perform,
        :logger_messages

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
          worker_instance.do_perform do
            worker_instance.perform(sqs_message, body)
          end
          worker_instance.after_perform(sqs_message, body)
        end
      end  # class methods

      self.finished_progress = 0

      def initialize
        @terminate         = false
        @perform_error     = nil
        @runtime_error     = nil
        @can_perform       = false
        @finished_perform  = false
        @logger_messages   = []
        @logger            = CPW::Logger::MultiLogger.new(CPW::logger, MonoLogger.new(CPW::Logger::WorkerLogDevice.new(self)))
      end

      def test?
        !!@test
      end

      def force?
        !!(body && body['force'])
      end

      def ingest_id
        body.try(:[], 'ingest_id')
      end

      def worker_id
        body.try(:[], 'worker_id')
      end

      def push_logger_message(message)
        @logger_messages.push(message)
      end

      def before_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#before_perform: #{body.inspect}\n"
        self.sqs_message, self.body = sqs_message, body
      end

      def do_perform
        logger.info "+++ #{self.class.name}#do_perform 'before lock_worker!' #{body.inspect}"
        begin
          if lock_worker!
            self.can_perform = true
            yield
            logger.info "+++ #{self.class.name}#do_perform 'finished perform' #{body.inspect}"
            self.finished_perform = true
          end
        rescue ResourceLoadError => ex
          logger.info "+++ #{self.class.name}#do_perform 'load error': #{ex.message}."
          self.runtime_error = ex
        rescue ResourceLockError => ex
          logger.info "+++ #{self.class.name}#do_perform 'lock error': #{ex.message}."
          # self.runtime_error = ex
        rescue => ex
          logger.info "+++ #{self.class.name}#do_perform worker exception caught ingest_id=#{ingest_id}, worker_id=#{worker_id}."
          self.runtime_error, self.perform_error = ex, ex
        end
      end

      def after_perform(sqs_message, body)
        logger.info "+++ #{self.class.name}#after_perform: #{body.inspect}\n"

        # Sprinkle a bit of joy...
        GC.start

        unlock_worker!
      end

      def terminate!
        @terminate = true
      end

      def increment_progress!(increment = 1, max_progress = finished_progress)
        if worker && worker.present?
          progress = worker.progress
          progress += increment
          update_worker({progress: progress}) if progress < max_progress
        end
      end

      protected

      def lock_worker!(attributes = {})
        logger.info "+++ #{self.class.name}#lock_worker! 'entry point' #{body.inspect}"
        raise ResourceLoadError, "Cannot find ingest_id in message body" unless ingest_id

        if worker_id
          update_worker({
            event: "start",
            instance_id: ec2_instance.try(:instance_id)
          })
        else
          create_worker({
            worker_name: self.class.name.underscore,
            event: "start",
            instance_id: ec2_instance.try(:instance_id)
          })
        end

        raise ResourceLoadError, "Cannot load worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}): worker not found" unless @worker.present?
        raise ResourceLoadError, "Cannot load ingest (ingest_id=#{ingest_id}, worker_id=#{worker_id}): ingest not found" unless @ingest.present?
        raise ResourceLockError, "Cannot lock worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}): errors #{@worker.errors.inspect}" unless @worker.errors.empty?
        raise ResourceLockError, "Cannot lock worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}): errors #{@worker.state}" unless @worker.state == :running

        true
      end

      def unlock_worker!(attributes = {})
        logger.info "+++ #{self.class.name}#unlock_worker! ingest_id=#{ingest_id}, worker_id=#{worker_id} entry point"
        attributes = attributes.reject {|k,v| v.nil?}

        if has_finished_perform?
          attributes.merge!({event: "finish"})
        elsif has_runtime_error?
          new_messages = {}
          new_messages["error"]     = "#{runtime_error.class.name}"
          new_messages["message"]   = "#{runtime_error.message}"
          new_messages["backtrace"] = runtime_error.backtrace if runtime_error.backtrace
          new_messages["logs"]      = logger_messages unless logger_messages.empty?
          attributes.merge!({event: "stop", messages: new_messages})
        end

        # update worker
        if !attributes.empty?
          logger.info "+++ #{self.class.name}#unlock_worker! ingest_id=#{ingest_id}, worker_id=#{worker_id} calling update_worker(#{attributes.inspect})"
          update_worker(attributes)
        end

        worker
      end

      def queue_name
        self.class.queue_name
      end

      def ec2_instance
        @ec2_instance ||= begin
          instance = nil
          unless CPW.development?
            metadata_endpoint = "http://169.254.169.254/latest/meta-data/"
            uri = URI.parse(metadata_endpoint + "instance-id")
            http = Net::HTTP.new(uri.host, uri.port)
            http.open_timeout = 0.2
            http.read_timeout = 0.2
            request = Net::HTTP::Get.new(uri.request_uri)
            response = http.request(request)
            instance_id = response.body
            ec2 = AWS::EC2.new
            instance = ec2.instances[instance_id]
          end
          instance
        rescue Net::OpenTimeout, Errno::EHOSTDOWN, Errno::ETIMEDOUT, Net::HTTPGatewayTimeOut, Net::HTTPRequestTimeOut
          nil
        end
      end

      def busy?
        @ingest.present? && !!@ingest.busy
      end

      def terminate?
        @terminate || (ingest.present? && !!ingest.terminate)
      end

      def lsh_index
        @lsh_index ||= begin
          storage = if ENV['REDIS_URL']
            LSH::Storage::RedisBackend.new({
              # :redis => { :host => '127.0.0.1', :port => 6379 },
              :redis => {:url => ENV['REDIS_URL']},
              :data_dir => '/tmp',
              :cache_vectors => false
            })
          else
            LSH::Storage::Memory.new
          end

          LSH::Index.new({
            :dim => ENV.fetch('LSH_INDEX_DIMENSIONS', 12288).to_i,
            :number_of_random_vectors => ENV.fetch('LSH_NUMBER_OF_RANDOM_VECTORS', 16).to_i,
            :number_of_independent_projections => ENV.fetch('LSH_NUMBER_OF_INDEPENDENT_PROJECTIONS', 150).to_i,
            :window => Float::INFINITY
          }, storage)
        end
      end

      private

      def finished_progress
        self.class.finished_progress.to_i
      end

      # TODO: obsolete, references in remove/reset/stop worker
      def update_ingest(attributes = {})
        logger.info "+++ #{self.class.name}#update_ingest id=#{ingest_id}, #{attributes.inspect}"
        @ingest = Ingest.secure_update(ingest_id, attributes, {logger: logger})
      end

      def create_worker(attributes = {})
        logger.info "+++ #{self.class.name}#create_worker ingest_id=#{ingest_id}, worker_id=#{worker_id}, #{attributes.inspect}"
        @worker, @ingest = Ingest::Worker.secure_create(ingest_id, attributes, {logger: logger})
      end

      def update_worker(attributes = {})
        logger.info "+++ #{self.class.name}#update_worker ingest_id=#{ingest_id}, worker_id=#{worker_id}, #{attributes.inspect}"
        @worker, @ingest = Ingest::Worker.secure_update(ingest_id, worker_id, attributes, {logger: logger})
      end

      def can_perform?
        !!@can_perform
      end

      def has_finished_perform?
        !!@finished_perform
      end

      def has_perform_error?
        !!@perform_error
      end

      def has_runtime_error?
        !!@runtime_error
      end
    end  # Base
  end  # Worker
end  # CPW
