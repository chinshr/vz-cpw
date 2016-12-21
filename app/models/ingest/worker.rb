class Ingest::Worker < CPW::Client::Base
  uri "ingests/(:ingest_id)/workers/(:id)"
  include_root_in_json :worker

  belongs_to :ingest

  class << self
    @@semaphore = Mutex.new

    def secure_find(ingest_id, id, options = {})
      worker, ingest = nil, nil
      @@semaphore.synchronize do
        CPW::Client::Base.try_request(options) do
          worker = Ingest::Worker.where(ingest_id: ingest_id).find(id)
          ingest = worker.ingest if worker.present? && worker.ingest_id
        end
      end
      return worker, ingest
    end

    def secure_create(ingest_id, attributes = {}, options = {})
      worker, ingest = nil, nil
      @@semaphore.synchronize do
        CPW::Client::Base.try_request(options) do
          worker = Ingest::Worker.where(ingest_id: ingest_id).create(attributes)
          ingest = worker.ingest if worker.present? && worker.ingest_id
        end
      end
      return worker, ingest
    end

    def secure_update(ingest_id, id, attributes = {}, options = {})
      worker, ingest = nil, nil
      @@semaphore.synchronize do
        CPW::Client::Base.try_request(options) do
          worker = Ingest::Worker.new(ingest_id: ingest_id, id: id)
          worker.update_attributes(attributes)
          ingest = worker.ingest if worker.present? && worker.ingest_id
        end
      end
      return worker, ingest
    end

    def secure_lock(ingest_id, worker_id = nil, attributes = {}, options = {})
      worker, ingest = nil, nil
      raise ResourceLoadError, "Ingest::Worker#secure_lock, requires an ingest_id (ingest_id=#{ingest_id}, worker_id=#{worker_id}, attributes=#{attributes.inspect})." unless ingest_id.present?

      @@semaphore.synchronize do
        CPW::Client::Base.try_request(options) do |retries, tries_left|
          if retries > 0 && worker_id
            # find worker, only if update previously failed
            CPW::Client::Base.try_request(options) do
              worker = Ingest::Worker.where(ingest_id: ingest_id).find(worker_id)
              # hopefully transitioned to `running`?
              ingest = worker.ingest if worker.present? && worker.ingest_id
            end
          else
            if worker_id
              # update
              worker = Ingest::Worker.new(ingest_id: ingest_id, id: worker_id)
              worker.update_attributes(attributes)
              ingest = worker.ingest if worker.present? && worker.ingest_id
            else
              # create
              worker = Ingest::Worker.where(ingest_id: ingest_id).create(attributes)
              ingest, worker_id = worker.ingest, worker.id if worker.present? && worker.ingest_id
            end
          end
        end
      end
      # propagate error, if...
      raise ResourceLoadError, "Ingest::Worker#secure_lock, cannot load worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}, attributes=#{attributes.inspect}), worker not found." unless worker.present?
      raise ResourceLoadError, "Ingest::Worker#secure_lock, cannot load ingest (ingest_id=#{ingest_id}, worker_id=#{worker_id}, attributes=#{attributes.inspect}), ingest not found." unless ingest.present?
      raise ResourceLockError, "Ingest::Worker#secure_lock, cannot lock worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}, attributes=#{attributes.inspect}), worker errors #{worker.errors.inspect}." unless worker.errors.empty?
      raise ResourceLockError, "Ingest::Worker#secure_lock, cannot lock worker (ingest_id=#{ingest_id}, worker_id=#{worker_id}, attributes=#{attributes.inspect}), expected worker state `running`, instead was `#{worker.state}`." unless worker.state == :running
      # ...otherwise
      return worker, ingest
    end
  end  # class methods

  def present?
    !!self.try(:id)
  end

  def state
    attributes[:state].try(:to_sym)
  end

  def lock_count
    attributes[:lock_count] || 0
  end

  def status=(value)
  end

  def status
  end

end
