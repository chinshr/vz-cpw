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

  def test_chunk_type_for
    worker = build_worker
    chunk  = stubs("AudioChunk")

    chunk.stubs(:engine).returns(CPW::Speech::Engines::GoogleCloudSpeechEngine.new("a", {}))
    assert_equal "Chunk::GoogleCloudSpeechChunk", worker.send(:chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::NuanceDragonEngine.new("a", {}))
    assert_equal "Chunk::NuanceDragonChunk", worker.send(:chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::PocketsphinxEngine.new("a", {}))
    assert_equal "Chunk::PocketsphinxChunk", worker.send(:chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::SubtitleEngine.new("a"))
    assert_equal "Chunk::SubtitleChunk", worker.send(:chunk_type_for, chunk)

    chunk.stubs(:engine).returns(CPW::Speech::Engines::VoiceBaseEngine.new("a"))
    assert_equal "Chunk::VoiceBaseChunk", worker.send(:chunk_type_for, chunk)
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