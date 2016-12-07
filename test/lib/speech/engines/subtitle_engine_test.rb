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
    assert_equal 1, chunks[0].position
    assert_equal 1, chunks[0].id
    assert_not_nil chunks[0].best_text
    assert_in_delta 0.5, chunks[0].best_score, 0.1
    assert_equal CPW::Speech::STATUS_PROCESSED, chunks[0].status

    assert_equal 1, chunks[0].as_json['hypotheses'].size
    assert_equal chunks[0].best_text, chunks[0].as_json['hypotheses'][0]['utterance']
    assert_in_delta 0.5, chunks[0].best_score, chunks[0].as_json['hypotheses'][0]['confidence'], 0.01
    assert_equal 1, chunks[0].as_json['position']
    assert_equal 1, chunks[0].as_json['id']
    assert_equal CPW::Speech::STATUS_PROCESSED, chunks[0].as_json['status']

    assert_equal "Host: Estela de Carlotto! (Applause)", chunks[0].best_text
    assert_in_delta 15.8, chunks[0].offset, 0.1
    assert_equal chunks.first.offset, chunks[0].start_time
    assert_in_delta 3.13, chunks[0].duration, 0.1
    assert_in_delta 19.02, chunks[0].end_time, 0.1
  end

  def test_as_json
    engine = CPW::Speech::Engines::SubtitleEngine.new(File.join(fixtures_root, "example.en.srt"),
      {format: :srt})
    json = engine.as_json
    assert_not_nil json["chunks"]
    assert_equal 108, json["chunks"].size
    assert_equal 1, json["chunks"].last["hypotheses"].size
    assert_equal "(Applause)", json["chunks"].last["hypotheses"][0]['utterance']
  end

  def test_to_text
    engine = CPW::Speech::Engines::SubtitleEngine.new(File.join(fixtures_root, "example.en.srt"),
      {format: :srt})
    text = engine.to_text
    assert_not_nil text
    assert_equal 5224, text.size
  end

end
