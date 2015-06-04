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
        STAGE_CROWDOUT    = 450
        STAGE_FINISH      = 500
        STAGE_ARCHIVE     = 600
        STAGE_STOP        = -100
        STAGE_RESET        = -100
        STAGES = {
          start: STAGE_START, harvest: STAGE_HARVEST,
          transcode: STAGE_TRANSCODE, split: STAGE_SPLIT,
          crowdout: STAGE_CROWDOUT, finish: STAGE_FINISH,
          archive: STAGE_ARCHIVE
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
        has_many :tracks, uri: "ingests/:ingest_id/tracks/(:id)?none_of_types[]=document_track", class_name: "CPW::Client::Resources::Ingest::Track"
        has_many :tracks_including_master_track, uri: "ingests/:ingest_id/tracks/(:id)", class_name: "CPW::Client::Resources::Ingest::Track"

        scope :started, -> { where(any_of_status: Ingest::STATE_STARTED) }

        class << self
          @@workflow  = [:start, :harvest, :transcode, :split, :crowdout, :finish]
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
        end  # class methods

        # State inquiry
        # E.g. @ingest.state_created? || @ingest.state_starting?
        STATES.each do |inquiry, value|
          define_method("state_#{inquiry}?") do
            STATES[inquiry] == self.status
          end
        end

        def track
          tracks_including_master_track.where(any_of_types: ["document_track"]).first
        end

        def state
          STATES.keys[status].try(:to_sym)
        end

        def s3_upload_key
          upload['s3_key']
        end

        def s3_origin_bucket_name
          ENV['S3_OUTBOUND_BUCKET']
        end

        def s3_origin_key
          if self.track && self.track.try(:s3_key)
            # already uploaded as url
            self.track.s3_key
          else
            # to be used for main track
            File.join(uid, File.basename(s3_upload_key))
          end
        end

        def s3_origin_url
          if self.track && self.track.try(:s3_url)
            self.track.s3_url
          else
            File.join(ENV['S3_URL'], ENV['S3_OUTBOUND_BUCKET'], self.s3_origin_key)
          end
        end

        def s3_origin_mp3_key
          if self.track && self.track.try(:s3_mp3_key)
            # already uploaded as url
            self.track.s3_mp3_key
          elsif self.track && self.track.try(:s3_key)
            # when created
            "#{self.track.s3_key}.ac2.ab#{CPW::Worker::Transcode::MP3_BITRATE}k.mp3"
          else
            raise "Could not derive 's3_origin_mp3_key'"
          end
        end

        def s3_origin_mp3_url
          if self.track && self.track.try(:s3_mp3_url)
            self.track.s3_mp3_url
          else
            File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_mp3_key)
          end
        end

        def s3_origin_waveform_json_key
          if self.track && self.track.s3_waveform_json_key
            # already uploaded as url
            self.track.s3_waveform_json_key
          elsif self.track && self.track.s3_key
            # when being created
            "#{self.track.s3_key}.ac2.waveform.json"
          else
            raise "Could not derive 's3_origin_waveform_json_key'"
          end
        end

        def s3_origin_waveform_json_url
          if self.track && self.track.s3_waveform_json_url
            self.track.s3_waveform_json_url
          else
            File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_waveform_json_key)
          end
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
