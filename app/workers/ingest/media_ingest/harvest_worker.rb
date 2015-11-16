class Ingest::MediaIngest::HarvestWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  self.finished_progress = 19

  shoryuken_options queue: -> { queue_name },
    auto_delete: false, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    # Copy the object from inbound to outbound folder.
    # E.g. //inbound/xyz123 -> //outbound/13dba008-7ba2-4804-a534-43d03c65260b/xyz123
    s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], @ingest.s3_upload_key,
      @ingest.s3_origin_bucket_name, @ingest.s3_origin_key

    document_tracks = Ingest::Track.where(ingest_id: @ingest.id, any_of_types: "document")
    unless document_track = document_tracks.first
      # Create ingest's track and save s3 references
      # [POST] /api/ingests/:ingest_id/tracks.json?s3_url=abcd...
      Ingest::Track.create({
        type: "document_track",
        ingest_id: @ingest.id,
        s3_url: @ingest.s3_origin_url,
        ingest_iteration: @ingest.iteration
      })
    else
      # Update ingest's document track with new iteration number
      # [PUT] /api/ingests/:ingest_id/tracks/:id.json?s3_url=abcd
      document_track.update_attributes({
        ingest_iteration: @ingest.iteration
      })
    end

    # Delete uploaded object
    s3_delete_object_if_exists(ENV['S3_INBOUND_BUCKET'], @ingest.s3_upload_key)
  end
end
