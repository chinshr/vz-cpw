require 'test_helper.rb'

class CPW::Speech::Engines::IbmWatsonSpeechEngineTest < Test::Unit::TestCase

  def setup
    # v1:sessionless
    response_body = '{"results":[{"word_alternatives":[{"start_time":1.33,"alternatives":[{"confidence":1.0,"word":"I"}],"end_time":1.54}],"alternatives":[{"word_confidence":[["I",1.0],["like",0.8843797196608849],["pickles",0.957223902887191]],"confidence":0.946,"transcript":"I like pickles ","timestamps":[["I",1.33,1.54],["like",1.54,1.83],["pickles",1.83,2.46]]},{"transcript":"I liked pickles "}],"final":true}],"result_index":0}'
    stub_request(:post, /stream.watsonplatform.net\/speech-to-text\/api\/v1\/recognize/).
      to_return(status: 200, headers: {}, body: response_body)
  end

  def test_default_options
    engine = CPW::Speech::Engines::IbmWatsonSpeechEngine.new("foo.wav")
    assert_equal nil, engine.token
    assert_equal 16000, engine.sampling_rate
    assert_equal :sessionless, engine.method
    assert_equal "v1", engine.api_version
    assert_equal nil, engine.username
    assert_equal nil, engine.password
  end

  def test_prepare_model
    engine = CPW::Speech::Engines::IbmWatsonSpeechEngine.new("foo.wav",
      {locale: "en-UK", sampling_rate: 8000, username: "foo", password: "bar",
        method: :websocket})
    assert_equal "en-UK", engine.locale
    assert_equal 8000, engine.sampling_rate
    assert_equal "en-UK_NarrowbandModel", engine.send(:prepare_model, engine.locale)
    assert_equal "foo", engine.username
    assert_equal "bar", engine.password
    assert_equal :websocket, engine.method

    engine = CPW::Speech::Engines::IbmWatsonSpeechEngine.new("foo.wav",
      {locale: "en-US"})
    assert_equal "en-US", engine.locale
    assert_equal 16000, engine.sampling_rate
    assert_equal "en-US_BroadbandModel", engine.send(:prepare_model, engine.locale)
  end

  def test_should_v1_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :ibm_watson_speech_engine, :verbose => false, :api_version => "v1")
    assert_equal CPW::Speech::Engines::IbmWatsonSpeechEngine, audio.engine.class
    assert_equal "I like pickles ", audio.to_text
  end

  def test_should_v1_convert_audio_as_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :ibm_watson_speech_engine, :verbose => false, :api_version => "v1")
    json = audio.as_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 1, json["chunks"].first["hypotheses"].size
    assert_equal 3, json["chunks"].first["words"].size
  end

  def test_should_perform_with_block
    engine = CPW::Speech::Engines::IbmWatsonSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav")
    engine.perform do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles ", chunk.best_text
      assert_equal 0.946, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal [], chunk.errors
      # as_json
      as_json = chunk.as_json
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, as_json['status']
      assert_equal chunk.words.as_json, as_json['words']
    end
  end

end
