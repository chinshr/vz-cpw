require 'test_helper.rb'

class CPW::Speech::Chunkster
  include CPW::Speech::ProcessHelper
end

class CPW::Speech::ProcessHelperTest < Test::Unit::TestCase

  def setup
    @chunk = CPW::Speech::Chunkster.new
  end

  def test_should_get_processed_stages
    assert_equal [], @chunk.processed_stages.get
  end

  def test_should_to_a_processed_stages
    assert_equal [], @chunk.processed_stages.to_a
  end

  def test_should_set_processed_stages
    @chunk.processed_stages = :build
    assert_equal [:build], @chunk.processed_stages.to_a
  end

  def test_should_add_processed_stage
    @chunk.processed_stages.add(:build)
    assert_equal [:build], @chunk.processed_stages.to_a
    assert_equal CPW::Speech::ProcessHelper::ProcessedStages::PROCESSED_STAGES[:build], @chunk.processed_stages.bits
    @chunk.processed_stages.add(:build)
    assert_equal CPW::Speech::ProcessHelper::ProcessedStages::PROCESSED_STAGES[:build], @chunk.processed_stages.bits
  end

  def test_should_alias_push_processed_stage
    @chunk.processed_stages.push(:build)
    assert_equal [:build], @chunk.processed_stages.to_a
  end

  def test_should_not_add_unknown_stage
    @chunk.processed_stages << :foobar
    assert_equal [], @chunk.processed_stages.to_a
  end

  def test_should_add_operator_processed_stage
    @chunk.processed_stages << :build
    assert_equal [:build], @chunk.processed_stages.to_a
    @chunk.processed_stages << :encode
    assert_equal [:build, :encode], @chunk.processed_stages.to_a
    @chunk.processed_stages << :convert
    assert_equal [:build, :encode, :convert], @chunk.processed_stages.to_a
    @chunk.processed_stages << :extract
    assert_equal [:build, :encode, :convert, :extract], @chunk.processed_stages.to_a
  end

  def test_should_use_equal_operator
    @chunk.processed_stages << :build
    assert_equal true, @chunk.processed_stages == [:build]
  end

  def test_should_include
    assert_equal false, @chunk.processed_stages.include?(:build)
    @chunk.processed_stages << :build
    assert_equal true, @chunk.processed_stages.include?(:build)
  end

  def test_should_status
    @chunk.processed_stages << :build
    assert_equal CPW::Speech::ProcessHelper::ProcessedStages::PROCESSED_STAGES[:build], @chunk.processed_stages.status
  end

end
