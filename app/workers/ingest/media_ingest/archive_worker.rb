class Ingest::MediaIngest::ArchiveWorker < CPW::Worker::Base
  include CPW::Worker::Helper
  include CPW::Worker::ShoryukenHelper

  self.finished_progress = 99

  def perform(sqs_message, body)
    logger.info "+++ #{self.class.name}#perform, body #{body.inspect}"

    # Remove original file name and use mp3 files for s3_key
  end
end
