=begin
require File.expand_path '../../../test_helper.rb', __FILE__

class CPW::Speech::Engines::AttSpeechEngineTest < Test::Unit::TestCase
  def setup
    WebMock.disable_net_connect!

    # standard mode
    # oauth
    stub_request(:post, "https://api.att.com/oauth/token").
      to_return(:status => 200, :body => {"access_token"=>"hsb9TM57GiMwtqmqZlBExLmDgDS59fQS", "token_type"=>"bearer", "expires_in"=>157680000, "refresh_token"=>"MwVMzXhL3177gaCVSfsjCJV1cWvN5mHg"}.to_json, :headers => {})

    # post
    stub_request(:post, "https://api.att.com/speech/v3/speechToText").
       to_return(status: 200, headers: {}, body: {"Recognition"=>{"Info"=>{"metrics"=>{"audioBytes"=>112620, "audioTime"=>3.50999999}}, "NBest"=>[{"Confidence"=>1, "Grade"=>"accept", "Hypothesis"=>"i like pickles", "LanguageId"=>"en-US", "ResultText"=>"I like pickles.", "WordScores"=>[1, 1, 1], "Words"=>["I", "like", "pickles."]}], "ResponseId"=>"5a0c7dceecc5b581d8b4a1ca7e204203", "Status"=>"OK"}}.to_json)

    # custom mode
    # oauth
    stub_request(:post, "https://api.att.com/oauth/token").
      to_return(:status => 200, :body => {"access_token"=>"hsb9TM67GiMwtqmqZlBExLmDgDS59fQS", "token_type"=>"bearer", "expires_in"=>157680000, "refresh_token"=>"MwVMzXhL8177gaCVSfsjCJV1cWvN5mHg"}.to_json, :headers => {})

    # post
    stub_request(:post, "https://api.att.com/speech/v3/speechToTextCustom").
       to_return(status: 200, headers: {}, body: {"Recognition"=>{"Info"=>{"metrics"=>{"audioBytes"=>112620, "audioTime"=>3.50999999}}, "NBest"=>[{"Confidence"=>1, "Grade"=>"accept", "Hypothesis"=>"i like pickles", "LanguageId"=>"en-US", "ResultText"=>"I like pickles.", "WordScores"=>[1, 1, 1], "Words"=>["I", "like", "pickles."]}], "ResponseId"=>"5a0c7dceecc5b581d8b4a1ca7e204203", "Status"=>"OK"}}.to_json)
  end

  def test_should_standard_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :att_speech_engine, :api_key => "tgcqoeaecj4ff052a9ee8g0mzt9xti7p", :secret_key => "j7caqnrtvtiiqhtl1nhlmyp5li0dclxg",
      :mode => "standard", :verbose => false)
    json = audio.to_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, json["chunks"].first["status"]
    assert_equal 1, json["chunks"].first["hypotheses"].size
  end

  def test_should_standard_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :att_speech_engine, :api_key => "tgcqoeaecj4ff052a9ee8g0mzt9xti7p", :secret_key => "j7caqnrtvtiiqhtl1nhlmyp5li0dclxg",
      :mode => "standard", :verbose => false)
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles.", chunk.best_text
      assert_equal 1, chunk.best_score
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end

  def test_should_convert_audio_to_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :att_speech_engine, :api_key => "tgcqoeaecj4ff052a9ee8g0mzt9xti7p", :secret_key => "j7caqnrtvtiiqhtl1nhlmyp5li0dclxg",
      :mode => "custom", :verbose => false)
    json = audio.to_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, json["chunks"].first["status"]
    assert_equal 1, json["chunks"].first["hypotheses"].size
  end
end
=end
