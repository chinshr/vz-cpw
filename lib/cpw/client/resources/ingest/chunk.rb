module CPW
  module Client
    module Resources
      class Ingest::Chunk < CPW::Client::Base
        uri "ingests/:ingest_id/chunks/(:id)"
        include_root_in_json :chunk

        STATUS_UNPROCESSED         = 0
        STATUS_BUILT               = 1
        STATUS_ENCODED             = 2
        STATUS_TRANSCRIBED         = 3
        STATUS_BUILD_ERROR         = -1
        STATUS_ENCODING_ERROR      = -2
        STATUS_TRANSCRIPTION_ERROR = -3

        belongs_to :document
        belongs_to :ingest
        has_one :track
      end
    end
  end
end
