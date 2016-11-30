require 'test_helper.rb'

class CPW::Speech::AudioChunkTest < Test::Unit::TestCase

  def setup
    @engine   = stub('engine')
    @splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {engine: @engine})
  end

  def test_initialize
    segment = Diarize::Segment.new("audio", "start", "duration", "speaker_gender", "bandwidth", "speaker_id")
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {
      position: 1,
      response: {},
      speaker_segment: segment,
      external_id: "xyz"
    })

    assert_equal [], chunk.errors
    assert_equal CPW::Speech::AudioChunk::STATUS_UNPROCESSED, chunk.status
    assert_equal @splitter, chunk.splitter
    assert_equal false, chunk.copied
    assert_equal({}, chunk.raw_response)
    assert_equal({}, chunk.normalized_response)
    assert_equal nil, chunk.best_text
    assert_equal nil, chunk.best_score
    assert_equal 1.0, chunk.offset
    assert_equal 1.0, chunk.start_time
    assert_equal 5.0, chunk.duration
    assert_equal 6.0, chunk.end_time
    assert_equal 1, chunk.position
    assert_equal 1, chunk.id
    assert_equal segment, chunk.speaker_segment
    assert_equal "xyz", chunk.external_id
    assert_equal nil, chunk.poll_at
  end

  def test_attributes
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1, response: {}})
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

  def test_delegate_engine
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})

    assert_equal @splitter.engine, chunk.engine
    assert_equal @engine, chunk.engine
  end

  def test_delegate_base_file_type
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})

    @engine.stubs(:base_file_type).returns("flac")
    assert_equal @splitter.base_file_type, chunk.base_file_type
  end

  def test_delegate_source_file_type
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
    @engine.stubs(:source_file_type).returns("mp3")
    assert_equal @splitter.source_file_type, chunk.source_file_type
  end

  def test_duration
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal 5.0, chunk.duration
  end

  def test_start_time
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal 1.0, chunk.start_time
  end

  def test_end_time
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal 6.0, chunk.end_time
  end

  def test_best_text_and_to_s
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.best_text = "Wow!"
    assert_equal "Wow!", chunk.best_text
    assert_equal "Wow!", chunk.to_s
  end

  def test_best_score_and_confidence
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.best_score = 0.995
    assert_equal 0.995, chunk.best_score
    assert_equal 0.995, chunk.confidence
  end

  def test_words
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal [], chunk.words
  end

  def test_speaker
    speaker = Diarize::Speaker.new
    segment = Diarize::Segment.new("audio", "start", "duration", "speaker_gender", "bandwidth", "speaker_id")
    segment.expects(:speaker).returns(speaker)
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {speaker_segment: segment})
    assert_equal speaker, chunk.speaker
  end

  def test_as_json
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
    assert_equal({}, chunk.as_json)

    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1, normalized_response: {"status"=>3, "id"=>1, "hypotheses"=>[{"utterance"=>"I like pickles ", "confidence"=>0.946}]}})
    assert_not_nil chunk.as_json
    assert_equal 3, chunk.as_json['status']
    assert_equal 1, chunk.as_json['id']
  end

  def test_to_json
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
    assert_equal "{}", chunk.to_json

    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1, normalized_response: {"status"=>3, "id"=>1, "hypotheses"=>[{"utterance"=>"I like pickles ", "confidence"=>0.946}]}})
    assert_not_nil chunk.to_json
  end

  def test_is_unprocessed
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
  end

  def test_is_built
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.status = CPW::Speech::AudioChunk::STATUS_BUILT
    assert_equal false, chunk.unprocessed?
    assert_equal true, chunk.built?
  end

  def test_is_encoded
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.status = CPW::Speech::AudioChunk::STATUS_ENCODED
    assert_equal false, chunk.unprocessed?
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
  end

  def test_is_transcribed
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.status = CPW::Speech::AudioChunk::STATUS_TRANSCRIBED
    assert_equal false, chunk.unprocessed?
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal true, chunk.transcribed?
  end
end
