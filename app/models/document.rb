class Document < CPW::Client::Base
  uri "documents/(:id)"

  has_many :ingests, uri: 'ingests/(:id)', class_name: "Ingest"
  has_many :chunks, class_name: "Ingest::Chunk"
  has_one :track, uri: 'documents/:document_id/tracks/(:id)',
    class_name: "Document::Track"
end
