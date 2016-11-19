require 'test_helper.rb'

class CPW::Speech::Engines::SpeechmaticsEngineTest < Test::Unit::TestCase

  def setup
    stub_requests
  end

  def test_should_initialize
    engine = CPW::Speech::Engines::SpeechmaticsEngine.new("foo.wav",
      {api_version: "v9.9", user_id: "123456", auth_token: "xyz", external_id: "ext1234"})
    assert_equal nil, engine.media_url
    assert_equal "foo.wav", engine.media_file
    assert_equal "v9.9", engine.api_version
    assert_equal "123456", engine.user_id
    assert_equal "xyz", engine.auth_token
  end

  def xtest_should_v1_0_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :speechmatics_engine, :verbose => false,
      :user_id => "test-user-1", :auth_token => "test_token", :version => "v1.0")
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_v1_0_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :speechmatics_engine, :verbose => false,
      :user_id => "test-user-1", :auth_token => "test_token", :version => "v1.0")
    json = audio.to_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal true, json["chunks"].first.has_key?("text")
    assert_equal "I like pickles", json["chunks"].first["text"]
    assert_equal true, json["chunks"].first.has_key?("words")
    assert_equal audio.engine.chunks[0].words.as_json, json["chunks"].first["words"]
  end

  protected

  def stub_requests
    # upload stub
    upload_json = {'id' => 1, 'cost' => 5, 'check_wait' => 0.5, 'balance' => 95}.to_json
    stub_request(:post, "https://api.speechmatics.com/v1.0/user/test-user-1/jobs/?auth_token=test_token").
      with(:body => "model=en-US&diarisation=false&meta=1&notification=none&data_file=%2Ftmp%2Fi-like-pickles-chunk-1-00-00-00_00-00-00-03_52.wav",
        :headers => {'User-Agent'=>'Mozilla/5.0'}).
      to_return(:status => 200, :body => upload_json, :headers => {})

    # fetch stub
    fetch_json = {
      "job": {
        "lang": "en-US",
        "user_id": 1,
        "name": "hello_world.mp3",
        "duration": 2,
        "created_at": "Thu Jan 01 00:00:00 1970",
        "id": 1
      },
      "speakers": [
        {
          "duration": "2.000",
          "confidence": nil,
          "name": "F1",
          "time": "0.000"
        },
      ],
      "words": [
        {
          "duration": "1.000",
          "confidence": "0.943",
          "name": "I",
          "time": "0.021"
        },
        {
          "duration": "1.000",
          "confidence": "0.995",
          "name": "like",
          "time": "1.021"
        },
        {
          "duration": "1.000",
          "confidence": "0.976",
          "name": "pickles",
          "time": "2.021"
        }
      ],
      "format": "1.0"
    }.to_json
    stub_request(:get, "https://api.speechmatics.com/v1.0/user/test-user-1/jobs/1/transcript?auth_token=test_token").
      with(:headers => {'Content-Type'=>'application/json', 'User-Agent'=>'Mozilla/5.0'}).
      to_return(:status => 200, :body => fetch_json, :headers => {})
  end
end
