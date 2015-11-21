require 'test_helper.rb'

class CPW::Speech::AudioToTextTest < Test::Unit::TestCase
  def test_should_instantiate
    audio = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'),
      :engine => :base, :verbose => false)
    assert_equal false, audio.engine.blank?
  end
end
