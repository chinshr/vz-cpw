class Document::Track < CPW::Client::Base
  uri "documents/(:document_id)/tracks/(:id)"
  include_root_in_json :track

  has_one :document
  has_one :ingest

end
