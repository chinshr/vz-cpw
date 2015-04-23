module CPW
  class Worker::Harvest < Worker::Base
    extend Worker::Helper

    self.downstream_worker_class_name = "CPW::Worker::Transcode"

    def process
      # Copy the object from inbound to outbound folder.
      s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], ENV['S3_OUTBOUND_BUCKET'], ingest.s3_key

      # Update s3 references
      ingest.track.update_attribute(:s3_url, outbound_url(@ingest.upload.s3_key))

      # Delete uploaded object
      s3_delete_object_if_exists(APP_CONFIG['S3_INBOUND_BUCKET'], ingest.s3_key)
    end
  end
end