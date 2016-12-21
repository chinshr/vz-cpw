class Ingest::RemoveWorker < CPW::Worker::Base
  include CPW::Worker::Helper
  include CPW::Worker::ShoryukenHelper

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    update_ingest({status: Ingest::STATE_REMOVED})

    sqs_message.delete
  end
end
