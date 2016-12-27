class Ingest::Chunk < CPW::Client::Base
  include ::Speech::Stages::ProcessHelper

  uri "ingests/(:ingest_id)/chunks/(:id)"
  include_root_in_json :chunk

  belongs_to :document
  belongs_to :ingest
  has_one :track

  def processed_stages_mask
    attributes[:processed_stages_mask]
  end

  def processed_stages_mask=(bits)
    attributes[:processed_stages_mask] = bits
  end
end
