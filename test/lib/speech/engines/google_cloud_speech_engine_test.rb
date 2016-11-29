require 'test_helper.rb'

class CPW::Speech::Engines::GoogleCloudSpeechEngineTest < Test::Unit::TestCase
  def setup
    # v1beta1:syncrecognize
    stub_request(:post, /speech.googleapis.com\/v1beta1\/speech:syncrecognize/).
    to_return(status: 200, headers: {}, body: {
      "results" => [
        {
          "alternatives" => [
            {
              "transcript" => "I like pickles",
              "confidence" => 0.92408695
            },
            {
              "transcript" => "I like turtles",
              "confidence" => nil
            },
            {
              "transcript" => "I like tickles",
              "confidence" => nil
            },
          ],
        }
      ]
    }.to_json)
  end

  def test_default_options
    engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav", :key => "test-key")
    assert_equal "v1beta1", engine.version
    assert_equal "syncrecognize", engine.method
    assert_equal "test-key", engine.key
  end

  def test_assert_unsupported_api_version
    engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav", :key => "test-key", :version => "v1unsupported")
    assert_raise RuntimeError do
      engine.perform
    end
  end

  # v1beta1:syncrecognize

  def test_should_v1beta1_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_cloud_speech_engine, :verbose => false, :key => "test_key", :version => "v1beta1")
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_v1beta1_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_cloud_speech_engine, :verbose => false, :key => "test_key", :version => "v1beta1")
    json = audio.as_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 3, json["chunks"].first["hypotheses"].size
    assert_equal 1, json["chunks"].first["position"]
    assert_equal 1, json["chunks"].first["id"]
  end

  def test_should_v1beta1_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_cloud_speech_engine, :verbose => false, :key => "test_key", :version => "v1beta1")
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 0.92408695, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end
end
