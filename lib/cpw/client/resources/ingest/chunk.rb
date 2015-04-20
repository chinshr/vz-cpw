module CPW
  module Client
    module Resources
      class Ingest::Chunk < CPW::Client::Base
        uri "ingests/:ingest_id/chunks/(:id)"

        belongs_to :ingest
      end
    end
  end
end
