require 'test_helper.rb'

class CPW::Speech::Engines::SpeechmaticsEngine::WordsTest < Test::Unit::TestCase

  def setup
    @words_json = '[{"duration": "1.000", "confidence": "0.943", "name": "Hello", "time": "1.000"}, {"duration": "1.000", "confidence": "0.995", "name": "world", "time": "2.000"}, {"duration": "0.000", "confidence": null, "name": ".", "time": "2.010"}]'
    @words = CPW::Speech::Engines::SpeechmaticsEngine::Words.parse(@words_json)
  end

  def test_attributes
    assert_equal 3, @words.length

    # 1
    assert_equal 1, @words[0].position
    assert_equal "Hello", @words[0].word
    assert_equal 0.943, @words[0].confidence
    assert_equal 1.0, @words[0].start_time
    assert_equal 2.0, @words[0].end_time
    assert_equal 1.0, @words[0].duration

    # 2
    assert_equal 2, @words[1].position
    assert_equal "world", @words[1].word
    assert_equal 0.995, @words[1].confidence
    assert_equal 2.0, @words[1].start_time
    assert_equal 3.0, @words[1].end_time
    assert_equal 1.0, @words[1].duration

    # 3
    assert_equal 3, @words[2].position
    assert_equal ".", @words[2].word
    assert_equal nil, @words[2].confidence
    assert_equal 2.01, @words[2].start_time
    assert_equal 2.01, @words[2].end_time
    assert_equal 0.0, @words[2].duration
  end

  def test_to_json
    assert_equal '[{"p":1,"c":0.943,"s":1.0,"e":2.0,"w":"Hello"}]',
      @words.from(1).to(2).to_json
  end

  def test_to_speechmatics_json
    assert_equal '[{"duration":"1.0","confidence":"0.943","name":"Hello","time":"1.0"}]',
      @words.from(1).to(2).to_json(:speechmatics)
  end

  def test_scoped_from_to
    scoped_words = @words.from(1.0).to(2.0)
    assert_equal 1, scoped_words.size
    assert_equal "Hello", scoped_words[0].word
  end
end
