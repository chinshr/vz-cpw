class Ingest::StopWorker < CPW::Worker::Base
  include CPW::Worker::Helper
  include CPW::Worker::ShoryukenHelper

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    update_ingest({status: Ingest::STATE_STOPPED, terminate: true})

    terminate!
  end
end
