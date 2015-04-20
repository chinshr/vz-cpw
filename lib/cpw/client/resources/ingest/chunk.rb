module CPW
  module Client
    module Resource
      module Ingest
        class Chunk < CPW::Client::Base
          uri "ingests/:ingest_id/chunks/(:id)"

          belongs_to :ingest
        end
      end
    end
  end
end
