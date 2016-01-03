require 'test_helper.rb'

class CPW::Speech::AudioChunkWordTest < Test::Unit::TestCase

  def setup
    @word = CPW::Speech::AudioChunk::Word.new({"p" => 1, "s" => 1610, "e" => 1780, "c" => 0.7, "w" => "This", "m" => "article"})
  end

  def test_should_initialize_attributes
    assert_equal 1, @word.sequence
    assert_equal 1610, @word.start_time
    assert_equal 1780, @word.end_time
    assert_equal 0.7, @word.confidence
    assert_equal "This", @word.word
    assert_equal "article", @word.metadata
  end

  def test_aliases_attribute_getters
    assert_equal 1, @word.p
    assert_equal 1610, @word.s
    assert_equal 1780, @word.e
    assert_equal 0.7, @word.c
    assert_equal "This", @word.w
    assert_equal "article", @word.m
  end

  def test_aliases_attribute_setters
    assert_equal 2, (@word.p=(2))
    assert_equal 4444, (@word.s=(4444))
    assert_equal 5555, (@word.e=(5555))
    assert_equal 0.5, (@word.c=(0.5))
    assert_equal "help", (@word.w=("help"))
    assert_equal "punct", (@word.m=("punct"))
  end

  def test_clone
    clone = @word.clone
    assert_not_equal @word.object_id, clone.object_id
    assert_equal @word.sequence, clone.sequence
    assert_equal @word.start_time, clone.start_time
    assert_equal @word.end_time, clone.end_time
    assert_equal @word.confidence, clone.confidence
    assert_equal @word.word, clone.word
    assert_equal @word.metadata, clone.metadata
  end

  def test_empty
    assert_equal false, @word.empty?
    assert_equal true, CPW::Speech::AudioChunk::Word.new.empty?
    assert_equal false, CPW::Speech::AudioChunk::Word.new({"w" => "ok"}).empty?
  end

  def test_to_hash
    assert_equal({"p":1,"c":0.7,"s":1610,"e":1780,"w":"This"}, @word.to_hash)
  end

  def test_to_json
    assert_equal '{"p":1,"c":0.7,"s":1610,"e":1780,"w":"This"}', @word.to_json
  end

  # context "#=="

  def test_should_be_equal
    assert_equal true, (@word == @word)
  end

  def test_should_not_be_not_equal
    assert_equal false, (@word != @word)
  end

  def test_should_be_equal_with_error
    clone = @word.clone
    clone.error = "error"
    assert_equal true, (clone == @word)
  end

  def test_should_not_be_equal
    clone = @word.clone
    clone.word = "That"
    assert_equal false, (clone == @word)
  end

end
