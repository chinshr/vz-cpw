module CPW
  module Client
    module Resources
      class Ingest::Track < CPW::Client::Base
        uri "ingests/(:ingest_id)/tracks/(:id)"
        include_root_in_json :track

        has_one :document
        has_one :ingest
      end
    end
  end
end
