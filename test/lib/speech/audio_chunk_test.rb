require 'test_helper.rb'

class CPW::Speech::AudioChunkTest < Test::Unit::TestCase

  def setup
    @engine = CPW::Speech::Engines::SpeechEngine.new(File.join(fixtures_root, 'i-like-pickles.wav'))
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
    assert_equal CPW::Speech::STATUS_UNPROCESSED, chunk.status
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
    assert_equal false, chunk.extracted?

    assert_equal "/tmp/i-like-pickles-chunk-1-00-00-01_00-00-00-06_00.wav",
      chunk.file_name
    assert_equal nil, chunk.speaker_gmm_file_name
  end

  def test_attributes
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {position: 1})
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
    assert_equal chunk.best_text, chunk.to_text
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
    assert_equal true, chunk.unprocessed?
    chunk.build
    assert_equal false, chunk.unprocessed?
    assert_equal true, chunk.built?
    chunk.clean
  end

  def test_is_encoded_to_flac
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
    chunk.build.to_flac
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal "/tmp/i-like-pickles-chunk-00-00-01_00-00-00-06_00.flac",
      chunk.flac_file_name
    assert_equal true, File.exist?(chunk.flac_file_name)
    chunk.clean
    assert_equal false, File.exist?(chunk.flac_file_name)
  end

  def test_is_encoded_to_wav
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
    chunk.build.to_wav
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal "/tmp/i-like-pickles-chunk-00-00-01_00-00-00-06_00.wav",
      chunk.wav_file_name
    assert_equal true, File.exist?(chunk.wav_file_name)
    chunk.clean
    assert_equal false, File.exist?(chunk.wav_file_name)
  end

  def test_is_encoded_to_raw
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
    chunk.build.to_raw
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal "/tmp/i-like-pickles-chunk-00-00-01_00-00-00-06_00.raw",
      chunk.raw_file_name
    assert_equal true, File.exist?(chunk.raw_file_name)
    chunk.clean
    assert_equal false, File.exist?(chunk.raw_file_name)
  end

  def test_is_encoded_to_mp3
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
    chunk.build.to_mp3
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal "/tmp/i-like-pickles-chunk-00-00-01_00-00-00-06_00.ab128k.mp3",
      chunk.mp3_file_name
    assert_equal true, File.exist?(chunk.mp3_file_name)
    chunk.clean
    assert_equal false, File.exist?(chunk.mp3_file_name)
  end

  def test_to_waveform
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    chunk.build.to_waveform
    assert_equal "/tmp/i-like-pickles-chunk-00-00-01_00-00-00-06_00.waveform.json",
      chunk.waveform_file_name
    assert_equal true, File.exist?(chunk.waveform_file_name)
    chunk.clean
    assert_equal false, File.exist?(chunk.waveform_file_name)
  end

  def test_to_speaker_gmm
    speaker = Diarize::Speaker.new
    segment = Diarize::Segment.new("audio", "start", "duration", "speaker_gender", "bandwidth", "speaker_id")
    segment.expects(:speaker).returns(speaker).at_least(2)
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0, {speaker_segment: segment})
    assert_equal speaker, chunk.speaker
    speaker.expects(:save_model).with(chunk.send(:chunk_speaker_gmm_file_name))
    assert_equal chunk, chunk.to_speaker_gmm
    assert_equal "/tmp/i-like-pickles-chunk-speaker-speaker_id.gmm", chunk.speaker_gmm_file_name
  end

  def test_is_encoded_and_converted
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal true, chunk.unprocessed?
    chunk.build.to_wav
    assert_equal true, chunk.built?
    assert_equal true, chunk.encoded?
    assert_equal false, chunk.converted?
    chunk.processed_stages << :convert
    assert_equal true, chunk.converted?
  end

  def test_is_extracted
    chunk = CPW::Speech::AudioChunk.new(@splitter, 1.0, 5.0)
    assert_equal false, chunk.extracted?
    chunk.processed_stages.push(:extract)
    assert_equal true, chunk.extracted?
  end
end
