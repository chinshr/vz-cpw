module CPW
  module Worker
    class Harvest < Worker::Base
      extend Worker::Helper
      self.finished_progress = 5

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")
=begin

        # Copy the object from inbound to outbound folder.
        # E.g. //inbound/xyz123 -> //outbound/uid-123/xyz123
        s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], @ingest.s3_key, @ingest.s3_origin_bucket_name

        # Update ingest s3 references
        Track.create(document_id: @ingest.document, s3_url: @ingest.s3_origin_url)

        # Delete uploaded object
        s3_delete_object_if_exists(APP_CONFIG['S3_INBOUND_BUCKET'], @ingest.s3_key)
=end
      end
    end
  end
end