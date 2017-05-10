require 'test_helper.rb'

class CPW::Speech::Engines::SpeechmaticsEngine::SpeakersTest < Test::Unit::TestCase

  def setup
    @transcription_json = %(
    {
      "job": {
        "lang": "en-US",
        "user_id": 1,
        "name": "hello_world.mp3",
        "duration": 2,
        "created_at": "Thu Jan 01 00:00:00 1970",
        "id": 1
      },
      "speakers": [
        {
          "duration": "2.000",
          "confidence": 0.89,
          "name": "F1",
          "time": "0.000"
        },
        {
          "duration": "2.000",
          "confidence": 0.91,
          "name": "M1",
          "time": "3.000"
        }
      ],
      "words": [
        {
          "duration": "1.000",
          "confidence": "0.943",
          "name": "Hello",
          "time": "0.000"
        },
        {
          "duration": "1.000",
          "confidence": "0.995",
          "name": "world",
          "time": "1.000"
        },
        {
          "duration": "0.000",
          "confidence": null,
          "name": ".",
          "time": "2.000"
        },
        {
          "duration": "1.000",
          "confidence": "0.843",
          "name": "Foo",
          "time": "3.000"
        },
        {
          "duration": "1.000",
          "confidence": "0.791",
          "name": "bar",
          "time": "4.000"
        },
        {
          "duration": "0.000",
          "confidence": null,
          "name": "!",
          "time": "5.000"
        }
      ],
      "format": "1.0"
    })
    @speakers = CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse(@transcription_json)
  end

  def test_invalid_json_parse_error
    assert_raise CPW::Speech::Engines::SpeechmaticsEngine::Speakers::ParseError do
      CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse("")
    end

    assert_raise CPW::Speech::Engines::SpeechmaticsEngine::Speakers::ParseError do
      CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse('{}')
    end

    assert_raise CPW::Speech::Engines::SpeechmaticsEngine::Speakers::ParseError do
      CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse('{"foobar":null}')
    end
  end

  def test_invalid_hash_parse_error
    assert_raise CPW::Speech::Engines::SpeechmaticsEngine::Speakers::ParseError do
      CPW::Speech::Engines::SpeechmaticsEngine::Speakers.parse({})
    end
  end

  def test_attributes
    assert_equal 2, @speakers.length

    # 1
    assert_equal 1, @speakers[0].sequence
    assert_equal 2.0, @speakers[0].duration
    assert_equal 0.89, @speakers[0].confidence
    assert_equal "F1", @speakers[0].name
    assert_equal 0.0, @speakers[0].time

    # 2
    assert_equal 2, @speakers[1].position
    assert_equal 2.0, @speakers[1].duration
    assert_equal 0.91, @speakers[1].confidence
    assert_equal "M1", @speakers[1].name
    assert_equal 3, @speakers[1].time
  end

  def test_scoped_from_to
    scoped_speakers = @speakers.from(0.0).to(2.0)
    assert_equal 1, @speakers.from(0.0).to(2.0).size
    assert_equal "F1", @speakers.from(0.0).to(2.0)[0].name
    assert_equal 0, @speakers.from(0.0).to(0.0).size
    assert_equal 0, @speakers.from(2).to(2.99).size
    assert_equal 0, @speakers.from(2).to(4.99).size
    assert_equal 1, @speakers.from(2).to(5).size
    assert_equal "M1", @speakers.from(2).to(5)[0].name
  end

  def test_as_json
    assert_equal [{"duration":2.0,"confidence":0.89,"name":"F1","time":0.0}],
      @speakers.from(0.0).to(2.0).as_json
  end

  def test_to_json
    assert_equal '[{"duration":2.0,"confidence":0.89,"name":"F1","time":0.0}]',
      @speakers.from(0.0).to(2.0).to_json
  end

  def test_speaker_words
    assert_equal "Hello world.", @speakers[0].words.to_s
    assert_equal "Foo bar!", @speakers[1].words.to_s
  end
end
