class Ingest::MediaIngest::ArchiveWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  self.finished_progress = 99

  shoryuken_options queue: -> { queue_name },
    auto_delete: true, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    # Remove original file name and use mp3 files for s3_key
  end

end
