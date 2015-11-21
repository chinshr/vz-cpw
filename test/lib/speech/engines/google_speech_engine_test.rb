require 'test_helper.rb'

class CPW::Speech::Engines::GoogleSpeechEngineTest < Test::Unit::TestCase
  def setup
    # v1
    stub_request(:post, /www.google.com\/speech-api\/v1/).
    to_return(status: 200, headers: {}, body: {
      "status"=>0,"id"=>"ce178ea89f8b17d8e8298c9c7814700a-1",
      "hypotheses"=>[
        {"utterance"=>"I like pickles", "confidence"=>0.59408695},
        {"utterance"=>"I like turtles"},
        {"utterance"=>"I like tickles"},
        {"utterance"=>"I like to Kohl's"},
        {"utterance"=>"I Like tickles"},
        {"utterance"=>"I lyk tickles"},
        {"utterance"=>"I liked to Kohl's"}
      ]}.to_json)

    # v2
    stub_request(:post, /www.google.com\/speech-api\/v2/).
    to_return(status: 200, headers: {}, body: {
      "result" => [
        {
          "alternative" => [
            {
              "transcript" => "I like pickles",
              "confidence" => 0.59408695
            },
            {
              "transcript" => "I like turtles"
            },
            {
              "transcript" => "I like tickles"
            },
          ],
          "final" => true
        }
      ],
      "result_index" => 0
    }.to_json)
  end

  # v1
  def test_should_v1_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v1")
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_v1_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v1")
    json = audio.to_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 7, json["chunks"].first["hypotheses"].size
  end

  def test_should_v1_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v1")
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 0.59408695, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end

  # v2
  def test_should_v2_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v2", :key => "test_key")
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_v2_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v2", :key => "test_key")
    json = audio.to_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 3, json["chunks"].first["hypotheses"].size
  end

  def test_should_v2_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :google_speech_engine, :verbose => false, :version => "v2", :key => "test_key")
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 0.59408695, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end
end