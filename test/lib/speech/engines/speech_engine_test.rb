require 'test_helper.rb'

class CPW::Speech::Engines::SpeechEngineTest < Test::Unit::TestCase

  def test_default_settings
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal [], engine.chunks
    assert_equal 2, engine.max_results
    assert_equal 3, engine.max_retries
    assert_equal "en-US", engine.locale
    assert_equal CPW::logger, engine.logger
    assert_equal :flac, engine.base_file_type
    assert_equal nil, engine.source_file_type
    assert_equal nil, engine.chunk_duration
    assert_equal false, engine.verbose
    assert_equal :auto, engine.split_method
    assert_equal({}, engine.split_options)
    assert_equal false, engine.perform_threaded?
    assert_equal 10, engine.max_threads
    assert_equal 1, engine.retry_delay
    assert_equal 360, engine.max_poll_retries
    assert_equal 5, engine.poll_retry_delay
    assert_equal "CPW-Speech/#{CPW::VERSION}", engine.user_agent
    assert_equal nil, engine.extraction_engine
    assert_equal :auto, engine.extraction_mode
    assert_equal({}, engine.extraction_options)
    assert_equal [], engine.errors
    assert_equal({}, engine.normalized_response)
    assert_equal false, engine.performed?
  end

  def test_initialize
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {
      :perform_threaded => true,
      :chunk_duration => 99,
      :verbose => true,
      :split_method => :foobar,
      :split_options => {:model_base_url => "http://www.example.com"},
      :max_results => 88,
      :max_retries => 66,
      :max_threads => 11,
      :retry_delay => 55,
      :max_poll_retries => 999,
      :poll_retry_delay => 67,
      :user_agent => "Mozilla/5.0"
    })
    assert_equal "foo.wav", engine.media_file
    assert_equal true, engine.perform_threaded?
    assert_equal 99, engine.chunk_duration
    assert_equal 99, engine.chunk_duration
    assert_equal true, engine.verbose
    assert_equal :foobar, engine.split_method
    assert_not_nil engine.split_options
    assert_equal "http://www.example.com", engine.split_options[:model_base_url]
    assert_equal 88, engine.max_results
    assert_equal 66, engine.max_retries
    assert_equal 11, engine.max_threads
    assert_equal 55, engine.retry_delay
    assert_equal 999, engine.max_poll_retries
    assert_equal 67, engine.poll_retry_delay
    assert_equal "Mozilla/5.0", engine.user_agent
  end

  def test_locale
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal "en-US", engine.locale

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {:locale => "en-GB"})
    assert_equal "en-GB", engine.locale
  end

  def test_logger
    logger = ::Logger.new(STDOUT)
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {:logger => logger})
    assert_equal logger, engine.logger
  end

  def test_chunk_duration
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {:chunk_duration => 10})
    assert_equal 10, engine.chunk_duration
  end

  def test_split_method
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {:split_method => :diarize})
    assert_equal :diarize, engine.split_method

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal :auto, engine.split_method
  end

  def test_auto_splitter_options
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav",
      {:chunk_duration => 10, :engine => engine, :split_method => :auto})
    options = engine.send(:audio_splitter_options)
    assert_equal 10, options[:chunk_duration]
    assert_equal engine, options[:engine]
    assert_equal :auto, options[:split_method]
  end

  def test_audio_split_options
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    options = engine.send(:audio_splitter_options, {
      engine: engine,
      chunk_duration: 99,
      verbose: true,
      locale: "es-AR",
      split_method: :diarize,
      split_options: {:mode => :foo}
    })
    assert_equal 6, options.keys.size
    assert_equal engine, options[:engine]
    assert_equal 99, options[:chunk_duration]
    assert_equal true, options[:verbose]
    assert_equal "es-AR", options[:locale]
    assert_equal :diarize, options[:split_method]
    assert_equal({:mode => :foo}, options[:split_options])
  end

  def test_extraction_engine_class_for
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal CPW::Speech::Engines::IbmWatsonAlchemyEngine, engine.send(:extraction_engine_class_for, :ibm_watson_alchemy_engine)
    assert_equal nil, engine.send(:extraction_engine_class_for, :foo)
    assert_equal nil, engine.send(:extraction_engine_class_for, nil)
  end

  def test_extraction_engine_options
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal({include: [:keyword_extraction]}, engine.send(:extraction_engine_options, {extraction_options: {include: [:keyword_extraction]}}))
    assert_equal({}, engine.send(:extraction_engine_options, {extraction_options: {include: []}}))
    assert_equal({}, engine.send(:extraction_engine_options, {extraction_options: {}}))
    assert_equal({}, engine.send(:extraction_engine_options, {extraction_options: nil}))
    assert_equal({}, engine.send(:extraction_engine_options, {}))
    engine.extraction_options = {include: [:keyword_extraction]}
    assert_equal({include: [:keyword_extraction]}, engine.send(:extraction_engine_options))
  end

  def test_abstract_convert_method
    speech_engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_raise CPW::Speech::NotImplementedError do
      speech_engine.send(:convert, nil)
    end
  end

  def test_should_not_be_perform_success_with_new_engine
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal false, engine.perform_success?
  end

  def test_add_chunk_error
    engine   = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {engine: engine})
    chunk    = CPW::Speech::AudioChunk.new(splitter, 1.0, 5.0, {position: 1})
    error    = StandardError.new("foobar error")
    result   = {}
    engine.send(:add_chunk_error, chunk, error, result)
    assert_equal 1, chunk.errors.size
    assert_equal "foobar error", chunk.errors[0]
    assert_equal 1, result['errors'].size
    assert_equal "foobar error", result['errors'][0]
  end

  def test_extract_chunks
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal false, engine.send(:extract_chunks?)

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {extraction_mode: :chunks})
    assert_equal true, engine.send(:extract_chunks?)

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {extraction_mode: :all})
    assert_equal true, engine.send(:extract_chunks?)
  end

  def test_extract_media
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal false, engine.send(:extract_media?)

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {extraction_mode: :media})
    assert_equal true, engine.send(:extract_media?)

    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav", {extraction_mode: :all})
    assert_equal true, engine.send(:extract_media?)
  end

  def test_extracted
    engine = CPW::Speech::Engines::SpeechEngine.new("foo.wav")
    assert_equal false, engine.extracted?
    engine.processed_stages << :extract
    assert_equal true, engine.extracted?
  end
end
