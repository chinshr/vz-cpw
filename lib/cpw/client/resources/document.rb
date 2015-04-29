module CPW
  module Client
    module Resources
      class Document < CPW::Client::Base
        uri "documents/(:id)"

        has_many :ingests
        has_many :chunks, class_name: "CPW::Client::Resources::Ingest::Chunk"
        has_one :track, uri: 'documents/:document_id/tracks/(:id)'
        accepts_nested_attributes_for :track

      end
    end
  end
end
