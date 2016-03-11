require 'test_helper.rb'

class WorkerHelperTest < Test::Unit::TestCase
  include CPW::Worker::Helper

  def test_waveform_sampling_rate
    assert_equal 30, waveform_sampling_rate(999, {:sampling_rate => 30})
    assert_equal 60, waveform_sampling_rate(60)
    assert_equal 27, waveform_sampling_rate(10 * 60 * 60)
    assert_equal 4, waveform_sampling_rate(60 * 60 * 60)
    assert_equal 1, waveform_sampling_rate(60 * 60 * 60 * 60)
  end

end
