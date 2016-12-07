class Ingest::Chunk < CPW::Client::Base
  uri "ingests/(:ingest_id)/chunks/(:id)"
  include_root_in_json :chunk

  belongs_to :document
  belongs_to :ingest
  has_one :track
end
