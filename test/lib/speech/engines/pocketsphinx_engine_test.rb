require 'test_helper.rb'

class CPW::Speech::Engines::PocketsphinxEngineTest < Test::Unit::TestCase
  def setup
    @configuration = ::Pocketsphinx::Configuration.default
    @configuration['vad_prespeech']  = 20
    @configuration['vad_postspeech'] = 45
    @configuration['vad_threshold']  = 2
  end

  def test_should_convert_audio_to_text
    engine = CPW::Speech::Engines::PocketsphinxEngine.new(File.join(fixtures_root, "goforward.raw"),
      @configuration, {source_file_type: :raw})

    engine.perform(locale: "en-US", basefolder: "/tmp").each do |chunk|
      assert_equal 1, chunk.id
      assert_not_nil chunk.best_text
      assert_equal true, chunk.best_score > 0.3
      assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunk.status

      assert_equal chunk.best_text, chunk.response['hypothesis']
      assert_equal "go forward ten meters", chunk.best_text
      assert_equal chunk.best_score, chunk.response['posterior_prob']
      assert_equal true, chunk.best_score >= 0.59 && chunk.best_score <= 0.6
      assert_equal 2.55, chunk.duration

      assert chunk.response['hypothesis']
      assert chunk.response['path_score']
      assert chunk.response['posterior_prob']

      assert chunk.response['words']
      assert_equal "go", chunk.response['words'][1]['word']
      assert chunk.response['words'][1]['start_frame']
      assert chunk.response['words'][1]['end_frame']
      assert chunk.response['words'][1]['start_time']
      assert chunk.response['words'][1]['end_time']
      assert chunk.response['words'][1]['acoustic_score']
      assert chunk.response['words'][1]['language_score']
      assert chunk.response['words'][1]['backoff_mode']
      assert chunk.response['words'][1]['posterior_prob']

      assert_equal 4, chunk.words.size
      assert_equal "go forward ten meters", chunk.words.map(&:word).join(" ")

      #1
      assert_equal 1, chunk.words[0].position
      assert_equal 0.48, chunk.words[0].start_time
      assert_equal 0.65, chunk.words[0].end_time
      assert_equal "go", chunk.words[0].word
      assert_in_delta 0.99, chunk.words[0].confidence, 0.1

      #2
      assert_equal 2, chunk.words[1].position
      assert_equal 0.66, chunk.words[1].start_time
      assert_equal 1.18, chunk.words[1].end_time
      assert_equal "forward", chunk.words[1].word
      assert_in_delta 0.99, chunk.words[1].confidence, 0.1

      #3
      assert_equal 3, chunk.words[2].position
      assert_equal 1.19, chunk.words[2].start_time
      assert_equal 1.54, chunk.words[2].end_time
      assert_equal "ten", chunk.words[2].word
      assert_in_delta 0.1, chunk.words[2].confidence, 0.1

      #3
      assert_equal 4, chunk.words[3].position
      assert_equal 1.55, chunk.words[3].start_time
      assert_equal 2.13, chunk.words[3].end_time
      assert_equal "meters", chunk.words[3].word
      assert_in_delta 0.29, chunk.words[3].confidence, 0.1
    end

  end
end
