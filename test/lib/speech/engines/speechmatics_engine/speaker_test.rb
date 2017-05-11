require 'test_helper.rb'

class CPW::Speech::Engines::SpeechmaticsEngine::SpeakerTest < Test::Unit::TestCase

  def setup
    @speaker_hash = {
      "duration": "2.000",
      "confidence": 0.89,
      "name": "F1",
      "time": "0.000"
    }
    @test_class = CPW::Speech::Engines::SpeechmaticsEngine::Speaker
    @speaker = @test_class.new(@speaker_hash)
  end

  def test_required_attributes
    assert_equal 2.0, @speaker.duration
    assert_equal 0.89, @speaker.confidence
    assert_equal "F1", @speaker.name
    assert_equal 0.000, @speaker.time
  end

  def test_be_valid
    assert_equal true, @speaker.valid?
    assert_equal true, @test_class.new({"duration": "2.000", "name": "F1", "time": "0.000"}).valid?
  end

  def test_not_be_valid
    assert_equal false, @test_class.new.valid?
    assert_equal false, @test_class.new({"name": "F1", "time": "0.000"}).valid?
    assert_equal false, @test_class.new({"duration": "2.000", "time": "0.000"}).valid?
    assert_equal false, @test_class.new({"duration": "2.000", "name": "F1"}).valid?
  end

  def test_end_time
    assert_equal 2.0, @speaker.end_time
  end

  def test_be_equal
    assert_equal true, @speaker == @speaker
  end

  def test_not_be_equal
    other = @test_class.new(@speaker_hash)
    other.name = "foo"
    assert_equal false, @speaker == other
  end

  def test_be_empty
    assert_equal true, @test_class.new.empty?
  end

  def test_not_be_empty
    assert_equal false, @speaker.empty?
  end

  def test_as_json
    assert_equal({:confidence=>0.89, :duration=>2.0, :name=>"F1", :time=>0.0}, @speaker.as_json)
  end

  def test_to_json
    assert_equal "{\"duration\":2.0,\"confidence\":0.89,\"name\":\"F1\",\"time\":0.0}", @speaker.to_json
  end

  def test_words_accessor
    @speaker.words = []
    assert_equal [], @speaker.words
  end

  def test_words_attribute
    speaker = CPW::Speech::Engines::SpeechmaticsEngine::Speaker.new({words: []})
    assert_equal [], speaker.words
  end

end
