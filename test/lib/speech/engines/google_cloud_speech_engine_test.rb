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

  def test_descendant_of_speech_engine
    assert_equal CPW::Speech::Engines::SpeechEngine, CPW::Speech::Engines::GoogleCloudSpeechEngine.superclass
  end

  def test_default_options
    engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav", {
      :api_key => "test-key"
    })
    assert_equal "v1beta1", engine.api_version
    assert_equal "syncrecognize", engine.api_method
    assert_equal "test-key", engine.api_key
  end

  def test_base_url
    engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav", {
      :api_key => "test-key"
    })
    assert_equal nil, engine.base_url
    engine.send(:reset!)
    assert_equal "https://speech.googleapis.com/v1beta1/speech:syncrecognize?key=test-key",
      engine.base_url
  end

  def test_assert_unsupported_api_version
    engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new("#{fixtures_root}/i-like-pickles.wav",
      {:api_key => "test-key", :api_version => "v1unsupported"})
    assert_raise CPW::Speech::UnsupportedApiError do
      engine.perform
    end
  end

  # v1beta1:syncrecognize

  def test_should_v1beta1_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav", {
      :engine => :google_cloud_speech_engine,
      :verbose => false,
      :api_key => "test_key",
      :api_version => "v1beta1"
    })
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_v1beta1_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav", {
      :engine => :google_cloud_speech_engine,
      :verbose => false,
      :api_key => "test_key",
      :api_version => "v1beta1"
    })
    json = audio.as_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 3, json["chunks"].first["hypotheses"].size
    assert_equal 1, json["chunks"].first["position"]
    assert_equal 1, json["chunks"].first["id"]
  end

  def test_should_v1beta1_perform
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav", {
      :engine => :google_cloud_speech_engine,
      :verbose => false,
      :api_key => "test_key",
      :api_version => "v1beta1",
      :split_method => :diarize,
      :split_options => {
        :model_base_url => "http://www.example.com/bucket"
      }
    })
    audio.perform do |chunk|
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 0.92408695, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.5, chunk.duration
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.as_json['status']
      assert_equal [], chunk.errors
      # diarize
      assert_equal "S0", chunk.speaker_segment.speaker_id
      assert_equal "F", chunk.speaker_segment.speaker_gender
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.as_json['status']
      assert_equal true, chunk.as_json.has_key?('speaker_segment')
      assert_not_nil chunk.as_json['speaker_segment']['speaker_supervector_hash']
      assert_not_nil chunk.as_json['speaker_segment']['speaker_mean_log_likelihood']
      assert_equal chunk.speaker.model_uri, chunk.as_json['speaker_segment']['speaker_model_uri']
      assert_equal "http://www.example.com/bucket/S0.gmm", chunk.speaker.model_uri
      assert_equal true, File.exist?(chunk.speaker_gmm_file_name)
      assert_equal [:build, :encode, :convert], chunk.processed_stages.to_a
    end
    assert_equal true, audio.engine.send(:perform_success?)
  end

  def test_should_v1beta1_perform_threaded
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav", {
      :engine => :google_cloud_speech_engine,
      :verbose => false,
      :api_key => "test_key",
      :api_version => "v1beta1",
      :perform_threaded => true,
      :split_method => :diarize,
      :split_options => {
        :model_base_url => "http://www.example.com"
      }
    })
    audio.perform do |chunk|
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 0.92408695, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.5, chunk.duration
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.as_json['status']
      assert_equal [], chunk.errors
      # diarize
      assert_equal "S0", chunk.speaker_segment.speaker_id
      assert_equal "F", chunk.speaker_segment.speaker_gender
      assert_equal CPW::Speech::STATUS_PROCESSED, chunk.as_json['status']
      assert_equal true, chunk.as_json.has_key?('speaker_segment')
      assert_not_nil chunk.as_json['speaker_segment']['speaker_supervector_hash']
      assert_not_nil chunk.as_json['speaker_segment']['speaker_mean_log_likelihood']
      assert_equal chunk.speaker.model_uri, chunk.as_json['speaker_segment']['speaker_model_uri']
      assert_equal "http://www.example.com/bucket/S0.gmm", chunk.speaker.model_uri
      assert_equal true, File.exist?(chunk.speaker_gmm_file_name)
      assert_equal [:build, :encode, :convert], chunk.processed_stages.to_a
    end
  end

end
