require 'test_helper.rb'

class CPW::Speech::Engines::PocketsphinxEngineTest < Test::Unit::TestCase
  def setup
    @configuration = ::Pocketsphinx::Configuration.default
    @configuration['vad_prespeech']  = 20
    @configuration['vad_postspeech'] = 45
    @configuration['vad_threshold']  = 2
  end

  def test_default_options
    engine = CPW::Speech::Engines::PocketsphinxEngine.new("foo.wav")
    assert_not_nil engine.configuration
    assert_equal :raw, engine.base_file_type
    assert_equal nil, engine.source_file_type
  end

  def test_native_split_and_recognize
    engine = CPW::Speech::Engines::PocketsphinxEngine.new(File.join(fixtures_root, "goforward.raw"),
      {:configuration => @configuration, :source_file_type => :raw})

    engine.perform(locale: "en-US", basefolder: "/tmp").each do |chunk|
      assert_equal 1, chunk.position
      assert_equal 1, chunk.id
      assert_equal ::Speech::State::STATUS_PROCESSED, chunk.status
      assert_not_nil chunk.best_text
      assert_equal "go forward ten meters", chunk.best_text
      assert_in_delta 0.59, chunk.best_score, 0.01
      assert_equal 2.55, chunk.duration

      assert_equal chunk.best_text, chunk.raw_response['hypothesis']
      assert_equal chunk.best_score, chunk.raw_response['posterior_prob']
      assert chunk.raw_response['path_score']
      assert chunk.raw_response['posterior_prob']

      # words
      assert chunk.raw_response['words']
      assert_equal "go", chunk.raw_response['words'][1]['word']
      assert chunk.raw_response['words'][1]['start_frame']
      assert chunk.raw_response['words'][1]['end_frame']
      assert chunk.raw_response['words'][1]['start_time']
      assert chunk.raw_response['words'][1]['end_time']
      assert chunk.raw_response['words'][1]['acoustic_score']
      assert chunk.raw_response['words'][1]['language_score']
      assert chunk.raw_response['words'][1]['backoff_mode']
      assert chunk.raw_response['words'][1]['posterior_prob']

      assert_equal 4, chunk.words.size
      assert_equal "go forward ten meters", chunk.words.map(&:word).join(" ")

      # 1st word
      assert_equal ::Speech::State::STATUS_PROCESSED, chunk.status
      assert_equal 1, chunk.words[0].position
      assert_equal 0.48, chunk.words[0].start_time
      assert_equal 0.65, chunk.words[0].end_time
      assert_equal "go", chunk.words[0].word
      assert_in_delta 0.99, chunk.words[0].confidence, 0.1

      # 2nd word
      assert_equal ::Speech::State::STATUS_PROCESSED, chunk.status
      assert_equal 2, chunk.words[1].position
      assert_equal 0.66, chunk.words[1].start_time
      assert_equal 1.18, chunk.words[1].end_time
      assert_equal "forward", chunk.words[1].word
      assert_in_delta 0.99, chunk.words[1].confidence, 0.1

      # 3rd word
      assert_equal ::Speech::State::STATUS_PROCESSED, chunk.status
      assert_equal 3, chunk.words[2].position
      assert_equal 1.19, chunk.words[2].start_time
      assert_equal 1.54, chunk.words[2].end_time
      assert_equal "ten", chunk.words[2].word
      assert_in_delta 0.1, chunk.words[2].confidence, 0.1

      # 4th word
      assert_equal ::Speech::State::STATUS_PROCESSED, chunk.status
      assert_equal 4, chunk.words[3].position
      assert_equal 1.55, chunk.words[3].start_time
      assert_equal 2.13, chunk.words[3].end_time
      assert_equal "meters", chunk.words[3].word
      assert_in_delta 0.29, chunk.words[3].confidence, 0.1
    end
  end

  def test_diarize_split_and_decode
    engine = CPW::Speech::Engines::PocketsphinxEngine.new(
      File.join(fixtures_root, "will-and-juergen.wav"), {
        :configuration => @configuration,
        :source_file_type => :wav,
        :split_method => :diarize
    })
    chunks = []
    engine.perform(locale: "en-US", basefolder: "/tmp").each do |chunk|
      chunks.push(chunk)
    end
    assert_equal 5, chunks.size

    # 1st chunk
    assert_equal 1, chunks[0].id
    assert_equal ::Speech::State::STATUS_PROCESSED, chunks[0].status
    assert_in_delta 2.5, chunks[0].duration, 0.1
    assert_in_delta 0.0, chunks[0].offset, 0.1
    assert_equal "M", chunks[0].speaker.gender
    assert_not_nil chunks[0].best_text
    assert_in_delta 0.5, chunks[0].best_score, 0.1
    assert_equal 7, chunks[0].words.size

    # 2nd chunk
    assert_equal 2, chunks[1].id
    assert_equal ::Speech::State::STATUS_PROCESSED, chunks[1].status
    assert_in_delta 17.2, chunks[1].duration, 0.1
    assert_in_delta 2.5, chunks[1].offset, 0.1
    assert_equal "M", chunks[1].speaker.gender
    assert_not_nil chunks[1].best_text
    assert_in_delta 0.4, chunks[1].best_score, 0.1
    assert_equal 51, chunks[1].words.size

    # 3rd chunk
    assert_equal 3, chunks[2].id
    assert_equal ::Speech::State::STATUS_PROCESSED, chunks[2].status
    assert_in_delta 13.6, chunks[2].duration, 0.1
    assert_in_delta 19.75, chunks[2].offset, 0.1
    assert_equal "M", chunks[2].speaker.gender
    assert_not_nil chunks[2].best_text
    assert_in_delta 0.4, chunks[2].best_score, 0.1
    assert_equal 41, chunks[2].words.size

    # 4th chunk
    assert_equal 4, chunks[3].id
    assert_equal ::Speech::State::STATUS_PROCESSED, chunks[3].status
    assert_in_delta 14.6, chunks[3].duration, 0.1
    assert_in_delta 33.6, chunks[3].offset, 0.1
    assert_equal "M", chunks[3].speaker.gender
    assert_not_nil chunks[3].best_text
    assert_in_delta 0.3, chunks[3].best_score, 0.1
    assert_equal 51, chunks[3].words.size

    # 5th chunk
    assert_equal 5, chunks[4].id
    assert_equal ::Speech::State::STATUS_PROCESSED, chunks[4].status
    assert_in_delta 5.9, chunks[4].duration, 0.1
    assert_in_delta 48.2, chunks[4].offset, 0.1
    assert_equal "M", chunks[4].speaker.gender
    assert_not_nil chunks[4].best_text
    assert_in_delta 0.2, chunks[4].best_score, 0.1
    assert_equal 26, chunks[4].words.size
  end

end
