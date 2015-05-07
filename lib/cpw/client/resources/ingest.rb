module CPW
  module Client
    module Resources
      class Ingest < CPW::Client::Base
        uri "ingests/(:id)"
        include_root_in_json :ingest

        STAGE_START       = 100
        STAGE_HARVEST     = 200
        STAGE_TRANSCODE   = 300
        STAGE_SPLIT       = 400
        STAGE_FINISH      = 500
        STAGE_ARCHIVE     = 600
        STAGES = {
          start: STAGE_START, harvest: STAGE_HARVEST,
          transcode: STAGE_TRANSCODE, split: STAGE_SPLIT,
          finish: STAGE_FINISH, archive: STAGE_ARCHIVE
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
        has_many :chunks, uri: "ingests/:ingest_id/chunks/(:id)", class_name: "CPW::Client::Resources::Ingest::Chunk"
        has_one :track, uri: "ingests/:ingest_id/tracks/(:id)?is_master=1", class_name: "CPW::Client::Resources::Ingest::Track"
        has_many :tracks, uri: "ingests/:ingest_id/tracks/(:id)", class_name: "CPW::Client::Resources::Ingest::Track"

        scope :started, -> { where(any_of_status: Ingest::STATE_STARTED) }

        class << self
          @@workflow  = [:start, :harvest, :transcode, :split, :finish]
          @@semaphore = Mutex.new

          def workflow; @@workflow; end

          def secure_find(id)
            @@semaphore.synchronize do
              Ingest.find(id)
            end
          end

          def secure_update(id, attributes)
            @@semaphore.synchronize do
              Ingest.new(Ingest.find(id).update_attributes(attributes))
            end
          end
        end

        # State inquiry
        # E.g. @ingest.state_created? || @ingest.state_starting?
        STATES.each do |inquiry, value|
          define_method("state_#{inquiry}?") do
            STATES[inquiry] == self.status
          end
        end

        def state
          STATES.keys[status].try(:to_sym)
        end

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
          "#{self.s3_key}.ac2.ab#{CPW::Worker::Transcode::MP3_BITRATE}k.mp3"
        end

        def s3_origin_mp3_url
          File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_mp3_key)
        end

        def s3_origin_waveform_json_key
          "#{self.s3_key}.ac2.waveform.json"
        end

        def s3_origin_waveform_json_url
          File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_waveform_json_key)
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
