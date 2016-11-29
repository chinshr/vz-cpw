require 'test_helper.rb'

class CPW::Speech::Engines::NuanceDragonEngineTest < Test::Unit::TestCase
  def setup
    @base_url  = "https://dictation.nuancemobility.net:443"
    @app_id    = "NMDPTRIAL_chinshr20140326185635"
    @app_key   = "edb1acb2e50d02417b643e6dce510ea9dd565c4ad4725dcb8d807c96fe6304eb14b09ef9bea03a390578a6d3cab57ca70bd8f1df4b4eabd8cf276ecd8a72b99f&id=C4461956B60B"
    @device_id = "8CGoCMXyIcJosb2"
    stub_request(:post, "#{@base_url}/NMDPAsrCmdServlet/dictation?appId=#{@app_id}&appKey=#{@app_key}&id=#{@device_id}").
      to_return(status: 200, headers: {}, body: "I like pickles\n")
  end

  def test_should_convert_audio_to_text
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :nuance_dragon_engine, :verbose => false, :base_url => @base_url, :app_id => @app_id, :app_key => @app_key)
    assert_equal "I like pickles", audio.to_text
  end

  def test_should_convert_audio_as_json
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :nuance_dragon_engine, :verbose => false, :base_url => @base_url, :app_id => @app_id, :app_key => @app_key)
    json = audio.as_json
    assert_equal true, json.has_key?("chunks")
    assert_equal 1, json["chunks"].size
    assert_equal 3, json["chunks"].first["status"]
    assert_equal 1, json["chunks"].first["hypotheses"].size
  end

  def test_should_convert_audio_to_json_with_block
    audio = CPW::Speech::AudioToText.new("#{fixtures_root}/i-like-pickles.wav",
      :engine => :nuance_dragon_engine, :verbose => false, :base_url => @base_url, :app_id => @app_id, :app_key => @app_key)
    audio.to_json do |chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status
      assert_equal "I like pickles", chunk.best_text
      assert_equal 1, chunk.id
      assert_equal 0, chunk.offset
      assert_equal 3.52, chunk.duration
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, JSON.parse(chunk.captured_json)['status']
      assert_equal [], chunk.errors
    end
  end
end
