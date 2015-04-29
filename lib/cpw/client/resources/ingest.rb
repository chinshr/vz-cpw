module CPW
  module Client
    module Resources
      class Ingest < CPW::Client::Base
        uri "ingests/(:id)"
        include_root_in_json :ingest

        STAGE_START       = 0
        STAGE_HARVEST     = 100
        STAGE_TRANSCODE   = 200
        STAGE_TRANSCRIBE  = 300
        STAGE_INDEX       = 400
        STAGE_ARCHIVE     = 500
        STAGES = {
          start: STAGE_START, harvest: STAGE_HARVEST,
          transcode: STAGE_TRANSCODE, transcribe: STAGE_TRANSCRIBE,
          index: STAGE_INDEX, archive: STAGE_ARCHIVE
        }

        STATE_CREATED     = 0
        STATE_STARTING    = 1
        STATE_STARTED     = 2
        STATE_STOPPING    = 3
        STATE_STOPPED     = 4
        STATE_RESETTING   = 5
        STATE_RESET       = 6
        STATE_REMOVING    = 7
        STATE_REMOVED     = 8
        STATE_FINISHED    = 9
        STATE_RESTARTING  = 10
        STATES = {
          created: STATE_CREATED, starting: STATE_STARTING, started: STATE_STARTED, 
          stopping: STATE_STOPPING, stopped: STATE_STOPPED, resetting: STATE_RESETTING,
          reset: STATE_RESET, removing: STATE_REMOVING, removed: STATE_REMOVED, 
          finished: STATE_FINISHED,  restarting: STATE_RESTARTING
        }

        belongs_to :document
        accepts_nested_attributes_for :document
        has_many :ingest_chunks, class_name: "CPW::Client::Resources::Ingest::Chunk"
        accepts_nested_attributes_for :chunks
        has_many :tracks

        scope :started, -> { where(any_of_status: Ingest::STATE_STARTED) }

        def s3_origin_bucket_name
          File.join(ENV['S3_OUTBOUND_BUCKET'], self.uid)
        end

        def s3_origin_uri
          File.join(self.s3_origin_bucket_name, self.s3_key)
        end

        def s3_origin_url
          File.join(ENV['S3_URL'], self.s3_origin_uri)
        end

        def s3_origin_mp3_key
          "#{self.s3_key}.#{CPW::Worker::Transcode::MP3_BITRATE}.mp3"
        end

        def s3_origin_mp3_url
          File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_mp3_key)
        end

        def set_progress!(percent)
          new_progress = percent
          new_progress = new_progress > 100 ? 100 : new_progress
          update_attribute(:progress, new_progress)
        end
      end
    end
  end
end
