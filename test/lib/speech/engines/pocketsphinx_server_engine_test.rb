require 'test_helper.rb'

class CPW::Speech::Engines::PocketsphinxServerEngineTest < Test::Unit::TestCase
  def setup
    #stub_request(:post, /www.charlupa.com\/api\/v1\/recognize/).
    stub_request(:post, /127.0.0.1:9393\/recognize/).
    to_return(status: 200, headers: {}, body: {
      "status"=>0,"id"=>"4d00ffd9b1a101940bb3ed88c6b6300d",
      "hypotheses"=>[
        {"utterance"=>"I like pickles"},
        {"utterance"=>"I like turtles"},
        {"utterance"=>"I like tickles"},
        {"utterance"=>"I like to Kohl's"},
        {"utterance"=>"I Like tickles"},
        {"utterance"=>"I lyk tickles"},
        {"utterance"=>"I liked to Kohl's"}
      ]}.to_json)
  end

  def test_should_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :pocketsphinx_server_engine, :verbose => false)
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_convert_audio_as_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :pocketsphinx_server_engine, :verbose => false)
    json = audio.as_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 7, json["chunks"].first["hypotheses"].size
  end

  def test_should_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :pocketsphinx_server_engine, :verbose => false, :version => "v1")
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_SUCCESS, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_SUCCESS, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end
end
