module CPW
  module Client
    module Resources
      class Document < CPW::Client::Base
        uri "documents/(:id)"

        has_many :ingests, uri: 'ingests/(:id)', class_name: "CPW::Client::Resources::Ingest"
        has_many :chunks, class_name: "CPW::Client::Resources::Ingest::Chunk"
        has_one :track, uri: 'documents/:document_id/tracks/(:id)',
          class_name: "CPW::Client::Resources::Document::Track"
      end
    end
  end
end
