class Ingest::MediaIngest::TranscribeWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  shoryuken_options queue: -> { queue_name },
    auto_delete: true, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    ingest_chunk = Ingest::Chunk.where(ingest_id: ingest_id).find(chunk_id)
    if ingest_chunk.try(:id)
    else
      raise "Chunk with chunk_id=#{chunk_id} not found."
    end
  end

  protected

  def chunk_id
    result = body.try(:[], 'chunk_id')
    raise "No `chunk_id` found in message body #{body}" unless result
    result
  end
end
