require File.expand_path '../../../test_helper.rb', __FILE__

class CPW::Speech::Engines::PocketsphinxEngineTest < Test::Unit::TestCase
  def setup
    @configuration = ::Pocketsphinx::Configuration.default
    @configuration['vad_prespeech']  = 20
    @configuration['vad_postspeech'] = 45
    @configuration['vad_threshold']  = 2
  end

  def test_should_convert_audio_to_text
    engine = CPW::Speech::Engines::PocketsphinxEngine.new("#{fixtures_root}/i-like-pickles.wav",
      @configuration, {source_file_type: :raw})

    engine.perform(locale: "en-US", basefolder: "/tmp").each do |audio_chunk|
      assert_equal 1, audio_chunk.id
      assert_not_nil audio_chunk.best_text
      assert_equal true, audio_chunk.best_score > 0.3
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, audio_chunk.status
      assert audio_chunk.response['hypothesis']
      assert_equal audio_chunk.best_score, audio_chunk.response['path_score']
      assert audio_chunk.response['words']
      assert_equal true, audio_chunk.duration >= 2.55
    end

  end
end
