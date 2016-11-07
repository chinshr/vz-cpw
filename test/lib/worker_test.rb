require 'test_helper.rb'

class WorkerTest < Test::Unit::TestCase
  def setup
    logger = mock("logger")
    logger.stubs(:info)
    CPW::Worker::Base.any_instance.stubs(:logger).returns(logger)
  end

  def test_stage_name
    assert_equal "harvest", Ingest::MediaIngest::HarvestWorker.stage_name
    assert_equal "transcode", Ingest::MediaIngest::TranscodeWorker.stage_name
    assert_equal "split", Ingest::MediaIngest::SplitWorker.stage_name
    assert_equal "archive", Ingest::MediaIngest::ArchiveWorker.stage_name
  end

  def test_stage
    assert_equal :harvest_stage, Ingest::MediaIngest::HarvestWorker.stage
    assert_equal :transcode_stage, Ingest::MediaIngest::TranscodeWorker.stage
    assert_equal :split_stage, Ingest::MediaIngest::SplitWorker.stage
    assert_equal :archive_stage, Ingest::MediaIngest::ArchiveWorker.stage
  end

  def test_queue_name
    assert_equal "INGEST_REMOVE_TEST_QUEUE", Ingest::RemoveWorker.queue_name
    assert_equal "INGEST_MEDIA_INGEST_SPLIT_TEST_QUEUE", Ingest::MediaIngest::SplitWorker.queue_name
  end

  def test_finished_progress
    assert_equal 19, Ingest::MediaIngest::HarvestWorker.finished_progress
    assert_equal 29, Ingest::MediaIngest::TranscodeWorker.finished_progress
    assert_equal 89, Ingest::MediaIngest::SplitWorker.finished_progress
    assert_equal 99, Ingest::MediaIngest::ArchiveWorker.finished_progress
  end

  #--- instance methods

  def test_is_force?
    worker = Ingest::MediaIngest::HarvestWorker.new
    assert_equal false, worker.force?
    worker.body = {"force" => 1}
    assert_equal true, worker.force?
  end

  def test_has_ingest_id
    worker = Ingest::MediaIngest::HarvestWorker.new
    worker.body = {"ingest_id" => 999}
    assert_equal 999, worker.ingest_id
  end

  #--- protected methods

  def test_instance_queue_name
    worker = Ingest::MediaIngest::HarvestWorker.new
    assert_equal "INGEST_MEDIA_INGEST_HARVEST_TEST_QUEUE", worker.send(:queue_name)
  end

  #--- private methods

  def test_should_be_busy?
    stub_ingest({'busy'=>true})
    worker = Ingest::MediaIngest::HarvestWorker.new
    worker.ingest = Ingest.find(1)
    assert_equal true, worker.send(:busy?)
  end

  def test_should_not_be_busy?
    stub_ingest({'busy'=>false})
    worker = Ingest::MediaIngest::HarvestWorker.new
    worker.ingest = Ingest.find(1)
    assert_equal false, worker.send(:busy?)
  end

  def test_should_terminate?
    stub_ingest({'terminate'=>true})
    worker = Ingest::MediaIngest::HarvestWorker.new
    worker.ingest = Ingest.find(1)
    assert_equal true, worker.send(:terminate?)
  end

  def test_should_not_terminate?
    stub_ingest({'terminate'=>false})
    worker = Ingest::MediaIngest::HarvestWorker.new
    worker.ingest = Ingest.find(1)
    assert_equal false, worker.send(:terminate?)
    worker.instance_variable_set(:@terminate, true)
    assert_equal true, worker.send(:terminate?)
  end

  def test_can_perform?
    worker = Ingest::MediaIngest::HarvestWorker.new
    assert_equal false, worker.send(:can_perform?)
  end

  def test_has_perform_error?
    worker = Ingest::MediaIngest::HarvestWorker.new
    assert_equal false, worker.send(:has_perform_error?)
  end

end