module CPW
  class Worker::Transcode < Worker::Base
    self.downstream_worker_class_name = "CPW::Worker::Transcribe"
  end
end