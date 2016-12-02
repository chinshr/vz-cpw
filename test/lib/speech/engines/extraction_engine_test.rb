require 'test_helper.rb'

class CPW::Speech::Engines::ExtractionEngineTest < Test::Unit::TestCase

  def setup
    @speech_engine = stub('speech_engine')
    @splitter      = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {engine: @speech_engine})
    @chunk         = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
  end

  def test_default_settings
    extractor = CPW::Speech::Engines::ExtractionEngine.new(@speech_engine)
    assert_equal @speech_engine, extractor.speech_engine
    assert_equal({}, extractor.options)
  end

  def test_initialize_settings
    extractor = CPW::Speech::Engines::ExtractionEngine.new(@speech_engine, {include: [:keyword_extraction]})
    assert_equal({include: [:keyword_extraction]}, extractor.options)
  end

  def test_abstract_extract_method
    extractor = CPW::Speech::Engines::ExtractionEngine.new(@speech_engine)
    assert_raise CPW::Speech::NotImplementedError do
      extractor.extract(@chunk)
    end
  end

  def test_add_entity_error
    extractor = CPW::Speech::Engines::ExtractionEngine.new(@speech_engine)
    result = {}
    error = StandardError.new("foobar error")
    extractor.send(:add_entity_error, @chunk, error, result)
    assert_equal 1, @chunk.errors.size
    assert_equal "foobar error", @chunk.errors[0]
    assert_equal 1, result['errors'].size
    assert_equal "foobar error", result['errors'][0]
    assert_equal 1, @chunk.as_json['errors'].size
    assert_equal "foobar error", @chunk.as_json['errors'][0]
  end
end
