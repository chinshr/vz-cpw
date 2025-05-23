require 'test_helper.rb'

class SplitWorkerTest < Test::Unit::TestCase # Minitest::Test

  def test_should_find_sphinx_model_sources
    sources = build_worker('en-US').send(:sphinx_model_sources)
    assert_not_nil sources
    assert_not_nil sources['dict']
    assert_not_nil sources['lm']
    assert_not_nil sources['hmm']
  end

  def test_should_fallback_to_base_language
    sources = build_worker('en-AU').send(:sphinx_model_sources)
    assert_not_nil sources
    assert_not_nil sources['dict']
    assert_not_nil sources['lm']
    assert_not_nil sources['hmm']
  end

  def test_raise_error_with_unknown_locale
    assert_raise RuntimeError do
      build_worker('xx-YY').send(:sphinx_model_sources)
    end
  end

  def test_sphinx_model_with_dict
    assert_equal "/sphinx/en/cmudict-07a.dic", build_worker('en-US').send(:sphinx_model, "dict").gsub(CPW::models_root_path, '')
  end

  def test_sphinx_model_with_lm
    assert_equal "/sphinx/en/lm_giga_64k_nvp_3gram.lm.dmp", build_worker('en-US').send(:sphinx_model, "lm").gsub(CPW::models_root_path, '')
  end

  def test_sphinx_model_with_hmm
    assert_equal "/sphinx/en/voxforge_en_sphinx.cd_cont_5000/", build_worker('en-US').send(:sphinx_model, "hmm").gsub(CPW::models_root_path, '')
  end

  def test_raise_model_file_not_found
    File.stubs(:exists?).returns(false)
    assert_raise RuntimeError do
      build_worker('en-US').send(:sphinx_model, "dict")
    end
  end

  def test_ingest_chunk_type_for
    worker = build_worker
    chunk  = stubs("AudioChunk")

    # chunks
    chunk.stubs(:engine).returns(CPW::Speech::Engines::GoogleCloudSpeechEngine.new("a", {}))
    assert_equal "Chunk::GoogleCloudSpeechChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::NuanceDragonEngine.new("a", {}))
    assert_equal "Chunk::NuanceDragonChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::PocketsphinxEngine.new("a", {}))
    assert_equal "Chunk::PocketsphinxChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::SubtitleEngine.new("a"))
    assert_equal "Chunk::SubtitleChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::VoicebaseEngine.new("a"))
    assert_equal "Chunk::VoiceBaseChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::SpeechmaticsEngine.new("a"))
    assert_equal "Chunk::SpeechmaticsChunk", worker.send(:ingest_chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::IbmWatsonSpeechEngine.new("a"))
    assert_equal "Chunk::IbmWatsonSpeechChunk", worker.send(:ingest_chunk_type_for, chunk)

    # engine
    assert_equal "Chunk::GoogleCloudSpeechChunk", worker.send(:ingest_chunk_type_for, CPW::Speech::Engines::GoogleCloudSpeechEngine.new("a", {}))
  end

  def test_determine_transcription_engine_name_via_quality
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.quality").returns("high")
    engine_name = build_worker.send(:determine_transcription_engine_name)
    assert_equal "voicebase", engine_name
  end

  def test_determine_transcription_engine_name_via_engine
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.quality").returns(nil)
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.engine").returns("raspberry")
    engine_name = build_worker.send(:determine_transcription_engine_name)
    assert_equal "speechmatics", engine_name
  end

  def test_determine_transcription_engine_name_normalize_high_quality_and_spanish_locale
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.quality").returns(nil)
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.engine").returns("voicebase")
    engine_name = build_worker("es-ES").send(:determine_transcription_engine_name)
    assert_equal "speechmatics", engine_name
  end

  def test_determine_transcription_engine_default
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.quality").returns(nil)
    Ingest::MediaIngest::SplitWorker.any_instance.stubs(:ingest_metadata).with("config.transcription.engine").returns(nil)
    engine_name = build_worker.send(:determine_transcription_engine_name)
    assert_equal "google_cloud_speech", engine_name
  end

  protected

  def build_worker(locale = "en-US")
    stub_ingest({'locale' => locale})
    ingest = Ingest.find(1)
    worker = Ingest::MediaIngest::SplitWorker.new
    worker.ingest = ingest
    worker
  end

end