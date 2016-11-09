require 'test_helper.rb'

class Ingest::MediaIngest::TranscribeWorkerTest < Test::Unit::TestCase # Minitest::Test

  def setup
    @worker = build_worker
  end

  def test_no_chunk_id_found
    exception = assert_raises(RuntimeError) { @worker.perform(nil, {'ingest_id' => 1}) }
    assert_match(/No `chunk_id` found/, exception.message)
  end

  protected

  def build_worker
    stub_ingest({'locale' => "en-US"})
    ingest = Ingest.find(1)
    worker = Ingest::MediaIngest::TranscribeWorker.new
    worker.ingest = ingest
    worker
  end

end