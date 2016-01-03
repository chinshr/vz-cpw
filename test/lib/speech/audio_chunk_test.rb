require 'test_helper.rb'

class CPW::Speech::AudioChunkTest < Test::Unit::TestCase

  def setup
    @engine   = stub('engine')
    @splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {engine: @engine})
  end

  def test_attributes
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {id: 1, response: {}})
    chunk.best_text  = "sample"
    chunk.best_score = 0.86

    assert_equal @splitter, chunk.splitter

    assert_equal 1.0, chunk.offset
    assert_equal 1.0, chunk.start_time
    assert_equal 5.0, chunk.duration
    assert_equal 6.0, chunk.end_time
    assert_equal 1, chunk.id
    assert_equal 1, chunk.position

    assert_equal "sample", chunk.best_text
    assert_equal chunk.best_text, chunk.to_s

    assert_equal 0.86, chunk.best_score
    assert_equal chunk.best_score, chunk.confidence
  end

  def test_delegates
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {id: 1, response: {}})

    assert_equal @splitter.engine, chunk.engine
    assert_equal @engine, chunk.engine

    @engine.stubs(:base_file_type).returns("flac")
    assert_equal @splitter.base_file_type, chunk.base_file_type

    @engine.stubs(:source_file_type).returns("mp3")
    assert_equal @splitter.source_file_type, chunk.source_file_type
  end

end
