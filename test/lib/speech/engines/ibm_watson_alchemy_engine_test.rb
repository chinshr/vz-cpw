require 'test_helper.rb'

class CPW::Speech::Engines::IbmWatsonAlchemyEngineTest < Test::Unit::TestCase
  def setup
    @speech_engine = CPW::Speech::Engines::SpeechEngine.new(File.join(fixtures_root, 'i-like-pickles.wav'),
      {split_method: :basic})
    @splitter      = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {engine: @engine})
    @chunk         = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
    @extraction_engine = CPW::Speech::Engines::IbmWatsonAlchemyEngine.new(@speech_engine, {})
    stub_requests
  end

  def test_descendant_of_extraction_engine
    assert_equal CPW::Speech::Engines::ExtractionEngine, CPW::Speech::Engines::IbmWatsonAlchemyEngine.superclass
  end

  def test_indexer
    extraction_engine = CPW::Speech::Engines::IbmWatsonAlchemyEngine.new(@speech_engine)
    assert_equal "keywords", extraction_engine.send(:indexer, :keyword_extraction)
    assert_equal "authors", extraction_engine.send(:indexer, :author_extraction)
    assert_equal "keywords", extraction_engine.send(:indexer, 'keyword_extraction')
    assert_raise CPW::Speech::UnknownOperationError do
      extraction_engine.send(:indexer, :foobar_extractor)
    end
    assert_equal "concepts", extraction_engine.send(:indexer, :concept_tagging)
    assert_equal "entities", extraction_engine.send(:indexer, :entity_extraction)
    assert_equal "relations", extraction_engine.send(:indexer, :relation_extraction)
    assert_equal "sentiments", extraction_engine.send(:indexer, :sentiment_analysis)
    assert_equal "sentiments", extraction_engine.send(:indexer, :targeted_sentiment_analysis)
    assert_equal "taxonomy", extraction_engine.send(:indexer, :taxonomy)
    assert_equal "text", extraction_engine.send(:indexer, :text_extraction)
    assert_equal "title", extraction_engine.send(:indexer, :title_extraction)
  end

  def test_extract_keywords_from_chunk
    extraction_engine = CPW::Speech::Engines::IbmWatsonAlchemyEngine.new(@speech_engine, {
      api_key: "abcd1234",
      include: :keyword_extraction,
    })
    @chunk.stubs(:to_text).returns("I like pickles")
    assert_equal false, @chunk.stage_extracted?
    extraction_engine.extract(@chunk)
    assert_equal true, @chunk.stage_extracted?
    assert_equal @simple_keywords, @chunk.as_json['keywords']
    assert_equal ["pickle", "sauerkraut"], @chunk.keywords
    assert_equal ["pickle"], @chunk.keywords(0.49)
  end

  def test_extract_keywords_from_engine
    extraction_engine = CPW::Speech::Engines::IbmWatsonAlchemyEngine.new(@speech_engine, {
      api_key: "abcd1234",
      include: :keyword_extraction
    })
    @speech_engine.expects(:convert).returns([])
    @speech_engine.expects(:to_text).returns("I like pickles")

    assert_equal false, @speech_engine.stage_extracted?
    extraction_engine.extract(@speech_engine)
    assert_equal true, @speech_engine.stage_extracted?
    assert_equal @simple_keywords, @speech_engine.normalized_response['keywords']
    assert_equal ["pickle", "sauerkraut"], @speech_engine.keywords
    assert_equal ["pickle"], @speech_engine.keywords(0.49)
  end

  def test_extract_options_with_single_value
    ops = @extraction_engine.send(:extract_operations, {include: :keyword_extraction})
    assert_equal({keyword_extraction: {}}, ops)
  end

  def test_extract_options_with_array
    ops = @extraction_engine.send(:extract_operations,
      {include: [:keyword_extraction, :topic_extraction]})
    assert_equal({keyword_extraction: {}, topic_extraction: {}}, ops)
  end

  def test_extract_options_with_hash_and_options
    ops = @extraction_engine.send(:extract_operations,
      {include: {keyword_extraction: {emotion: true}}})
    assert_equal({keyword_extraction: {emotion: 1}}, ops)
  end

  protected

  def stub_requests
    @simple_keywords  = [{"relevance"=>"0.990504", "text"=>"pickle"}, {"relevance"=>"0.49", "text"=>"sauerkraut"}]
    keywords_response = {"keywords" => @simple_keywords}
    stub_request(:post, "https://access.alchemyapi.com/calls/text/TextGetRankedKeywords").
      with(:body => {"apikey"=>"abcd1234", "outputMode"=>"json", "text"=>"I like pickles"},
        :headers => {'Content-Type'=>'application/x-www-form-urlencoded', 'Host'=>'access.alchemyapi.com:443', 'User-Agent'=>/.*/}).
      to_return(:status => 200, :body => keywords_response.to_json, :headers => {})
  end
end
