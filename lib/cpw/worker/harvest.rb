module CPW
  class Worker::Harvest < Worker
    self.downstream_worker_class_name = "CPW::Worker::Transcode"
  end
end