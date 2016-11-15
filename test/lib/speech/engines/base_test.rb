require 'test_helper.rb'

class CPW::Speech::Engines::BaseTest < Test::Unit::TestCase

  def test_default_settings
    engine = CPW::Speech::Engines::Base.new("foo.wav")
    assert_equal({}, engine.captured_json)
    assert_equal 0.0, engine.score
    assert_equal 0, engine.segments
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
  end

  def test_logger
    logger = ::Logger.new(STDOUT)
    engine = CPW::Speech::Engines::Base.new("foo.wav", {:logger => logger})
    assert_equal logger, engine.logger
  end

  def test_chunk_duration
    engine = CPW::Speech::Engines::Base.new("foo.wav", {:chunk_duration => 10})
    assert_equal 10, engine.chunk_duration
  end

  def test_split_method
    engine = CPW::Speech::Engines::Base.new("foo.wav", {:split_method => :diarize})
    assert_equal :diarize, engine.split_method

    engine = CPW::Speech::Engines::Base.new("foo.wav")
    assert_equal :auto, engine.split_method
  end

  def test_auto_splitter_options
    engine = CPW::Speech::Engines::Base.new("foo.wav",
      {:chunk_duration => 10, :engine => engine, :split_method => :auto})
    options = engine.send(:audio_splitter_options)
    assert_equal 10, options[:chunk_duration]
    assert_equal engine, options[:engine]
    assert_equal :auto, options[:split_method]
  end
end
