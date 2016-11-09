require 'test_helper.rb'

class Ingest::MediaIngest::TranscribeWorkerTest < Test::Unit::TestCase # Minitest::Test

  def setup
    @worker = build_worker
  end

  def test_no_chunk_id_found
    exception = assert_raises(Exception) { @worker.perform }
    assert_match(/No `chunk_id` found/, exception.message)
  end

  protected

  def build_worker(body = {'worker_id' => 1})
    stub_ingest({'locale' => "en-US"})
    ingest = Ingest.find(1)
    worker = Ingest::MediaIngest::TranscribeWorker.new("", body)
    worker.ingest = ingest
    worker
  end

end