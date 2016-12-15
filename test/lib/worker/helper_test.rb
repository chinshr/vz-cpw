require 'test_helper.rb'


class WorkerHelperTest < Test::Unit::TestCase
  class TestWorker
    include CPW::Worker::Helper

    attr_accessor :ingest

    def initialize
      @ingest = stubs("Ingest")
      @ingest.stubs(:track).returns(nil)
      @ingest.stubs(:uid).returns("ingest-test-uid")
    end
  end

  setup do
    @worker = TestWorker.new
  end

  def test_waveform_sampling_rate
    assert_equal 30, @worker.waveform_sampling_rate(999, {:sampling_rate => 30})
    assert_equal 60, @worker.waveform_sampling_rate(60)
    assert_equal 30, @worker.waveform_sampling_rate(60 * 20)
    assert_equal 10, @worker.waveform_sampling_rate(60 * 60)
    assert_equal 5, @worker.waveform_sampling_rate(2 * 60 * 60)
    assert_equal 1, @worker.waveform_sampling_rate(10 * 60 * 60)
  end

  def test_s3_origin_base_url
    assert_equal "http://s3.amazonaws.com/vz-test-origin/", @worker.s3_origin_base_url
  end

  def test_s3_origin_ingest_base_url
    assert_equal "http://s3.amazonaws.com/vz-test-origin/ingest-test-uid/", @worker.s3_origin_ingest_base_url
  end

  def test_s3_origin_url_for
    assert_equal "http://s3.amazonaws.com/vz-test-origin/ingest-test-uid/foo.wav", @worker.s3_origin_url_for("foo.wav")
  end
end
