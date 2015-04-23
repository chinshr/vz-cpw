module CPW
  module Client
    module Resources
      class Ingest < CPW::Client::Base
        uri "ingests/(:id)"

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

        has_many :chunks

        scope :started, -> { where(any_of_status: Ingest::STATE_STARTED) }
      end
    end
  end
end
