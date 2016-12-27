require 'test_helper.rb'

class Ingest::ChunkTest < Test::Unit::TestCase
  setup do
    @chunk = Ingest::Chunk.new(attributes: {"processed_stages_mask": ::Speech::Stages::ProcessedStages.bits([:build, :encode, :convert])})
  end

  def test_get_processed_stages
    assert_equal [:build, :encode, :convert], @chunk.processed_stages.to_a
  end

  def test_set_processed_stages
    chunk = Ingest::Chunk.new
    chunk.processed_stages = [:build, :encode]
    assert_equal [:build, :encode], chunk.processed_stages.to_a
  end

  def test_add_processed_stages
    @chunk.processed_stages << :extract
    assert_equal [:build, :encode, :convert, :extract], @chunk.processed_stages.to_a
  end

  def test_set_processed_stages_from_audio_chunk
    audio_chunk = CPW::Speech::AudioChunk.new(CPW::Speech::AudioSplitter.new("#{fixtures_root}/i-like-pickles.wav"), 0, 1)
    audio_chunk.processed_stages = [:build, :encode]
    @chunk.processed_stages = audio_chunk.processed_stages
    assert_equal [:build, :encode], @chunk.processed_stages.to_a
  end

end
