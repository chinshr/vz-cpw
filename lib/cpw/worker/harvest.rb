module CPW
  module Worker
    class Harvest < Worker::Base
      extend Worker::Helper

      def perform(message)
        # Copy the object from inbound to outbound folder.
        # E.g. //inbound/xyz123 -> //outbound/uid-123/xyz123
        s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], @ingest.s3_key, @ingest.s3_origin_bucket_name

        # Update ingest s3 references
        Track.create(document_id: @ingest.document, s3_url: @ingest.s3_origin_url)

        # Delete uploaded object
        s3_delete_object_if_exists(APP_CONFIG['S3_INBOUND_BUCKET'], @ingest.s3_key)

        # Move to next stage
        CPW::Worker::Transcode.perform_async(message)
      ensure
        @ingest.update_attributes(progress: 5)
      end
    end
  end
end