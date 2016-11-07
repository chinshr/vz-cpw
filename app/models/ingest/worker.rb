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
  end  # class methods

  def present?
    !!self.try(:id)
  end

  def state
    attributes[:state].try(:to_sym)
  end

  def status=(value)
  end

  def status
  end

end
