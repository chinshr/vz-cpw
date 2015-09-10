require File.expand_path '../../test_helper.rb', __FILE__

class CPW::Speech::AudioToTextTest < Test::Unit::TestCase
  def test_should_instantiate
    audio = CPW::Speech::AudioSplitter.new(File.expand_path('../../fixtures/i-like-pickles.wav', __FILE__),
      :engine => :base, :verbose => false)
    assert_equal false, audio.engine.blank?
  end
end
