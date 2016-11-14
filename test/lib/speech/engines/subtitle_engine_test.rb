require 'test_helper.rb'

class CPW::Speech::Engines::SubtitleEngineTest < Test::Unit::TestCase

  def test_srt_perform
    engine = CPW::Speech::Engines::SubtitleEngine.new(File.join(fixtures_root, "example.en.srt"),
      {format: :srt, default_chunk_score: 0.5})

    chunks = []
    engine.perform(basefolder: "/tmp").each do |chunk|
      chunks.push(chunk)
    end

    assert_equal 108, chunks.size
    assert_equal 1, chunks.first.id
    assert_not_nil chunks.first.best_text
    assert_in_delta 0.5, chunks.first.best_score, 0.1
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks.first.status

    assert_equal chunks.first.best_text, chunks.first.response['text']
    assert_equal "Host: Estela de Carlotto! (Applause)", chunks.first.best_text
    assert_in_delta 15.8, chunks.first.offset, 0.1
    assert_equal chunks.first.offset, chunks.first.start_time
    assert_in_delta 3.13, chunks.first.duration, 0.1
    assert_in_delta 19.02, chunks.first.end_time, 0.1
  end

  def test_to_json
    engine = CPW::Speech::Engines::SubtitleEngine.new(File.join(fixtures_root, "example.en.srt"),
      {format: :srt})
    json = engine.to_json
    assert_not_nil json["chunks"]
    assert_equal 108, json["chunks"].size
    assert_equal "(Applause)", json["chunks"].last["text"]
  end

  def test_to_text
    engine = CPW::Speech::Engines::SubtitleEngine.new(File.join(fixtures_root, "example.en.srt"),
      {format: :srt})
    text = engine.to_text
    assert_not_nil text
    assert_equal 5224, text.size
  end

end
