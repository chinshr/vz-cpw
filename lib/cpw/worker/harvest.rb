module CPW
  module Worker
    class Harvest < Worker::Base
      include Worker::Helper
      self.finished_progress = 5

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        # Copy the object from inbound to outbound folder.
        # E.g. //inbound/xyz123 -> //outbound/13dba008-7ba2-4804-a534-43d03c65260b/xyz123
        s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], @ingest.s3_key, @ingest.s3_origin_bucket_name

        # Create ingest's track and save s3 references
        # [POST] /api/ingests/:ingest_id/tracks.rb?s3_url=abcd
        Ingest::Track.create(ingest_id: @ingest.id, s3_url: @ingest.s3_origin_url, ingest_iteration: @ingest.iteration)

        # Delete uploaded object
        s3_delete_object_if_exists(ENV['S3_INBOUND_BUCKET'], @ingest.s3_key)
      end
    end
  end
end