require 'test_helper.rb'

class CPW::Speech::Engines::VoicebaseEngineTest < Test::Unit::TestCase

  def test_should_initialize_with_media_url
    engine = CPW::Speech::Engines::VoicebaseEngine.new(
      "http://www.example.com/test.mp3")
    assert_equal "http://www.example.com/test.mp3", engine.media_url
    assert_equal nil, engine.media_id
  end

  def test_should_initialize_with_media_file
    media_file = File.join(fixtures_root, "i-like-pickles.wav")
    engine = CPW::Speech::Engines::VoicebaseEngine.new(media_file)
    assert_equal media_file, engine.media_file
  end

  def test_should_external_id
    engine = CPW::Speech::Engines::VoicebaseEngine.new(
      "http://www.example.com/test.mp3", {external_id: "abcd1234"})
    assert_equal "abcd1234", engine.external_id
  end

  def test_should_clean
    engine = new_engine
    engine.stubs(:delete_file)
    engine.clean
  end

  def test_locale
    engine = new_engine
    engine.stubs(:split).returns([])

    engine.perform(locale: "en-US")
    assert_equal "en", engine.client.locale

    engine.perform(locale: "en")
    assert_equal "en", engine.client.locale

    engine.perform(locale: "es-ES")
    assert_equal "es", engine.client.locale

    engine.perform(locale: "es-AR")
    assert_equal "es", engine.client.locale

    engine.perform(locale: "es-MX")
    assert_equal "es-MEX", engine.client.locale

    assert_raise CPW::Speech::Engines::VoicebaseEngine::UnsupportedLocale do
      engine.perform(locale: "ru")
    end
  end

  def test_should_split
    engine = new_engine
    chunks = engine.perform(basefolder: "/tmp")

    assert_equal 5, chunks.size
    #1
    assert_equal 1, chunks[0].position
    assert_equal 0.31, chunks[0].start_time
    assert_equal 6.64, chunks[0].end_time
    assert_equal 6.33, chunks[0].duration
    assert_equal "In the beginning got screwed in the heavens of the art now the earth was formless and empty,",
      chunks[0].to_s
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks[0].status
    assert_in_delta 0.67, chunks[0].confidence, 0.01
    assert_equal 19, chunks[0].words.size

    #2
    assert_equal 2, chunks[1].position
    assert_equal 6.64, chunks[1].start_time
    assert_equal 13.67, chunks[1].end_time
    assert_equal 7.03, chunks[1].duration
    assert_equal "darkness was over the surface of the deep of the Spirit of God was hovering over the waters.",
      chunks[1].to_s
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks[1].status
    assert_in_delta 0.95, chunks[1].confidence, 0.01
    assert_equal 19, chunks[1].words.size

    #3
    assert_equal 3, chunks[2].position
    assert_equal 13.67, chunks[2].start_time
    assert_equal 18.78, chunks[2].end_time
    assert_in_delta 5.11, chunks[2].duration, 0.01
    assert_equal "and God said let there be light and there was light.",
      chunks[2].to_s
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks[2].status
    assert_in_delta 0.94, chunks[2].confidence, 0.01
    assert_equal 12, chunks[2].words.size

    #4
    assert_equal 4, chunks[3].position
    assert_equal 18.78, chunks[3].start_time
    assert_equal 24.58, chunks[3].end_time
    assert_in_delta 5.79, chunks[3].duration, 0.01
    assert_equal "God saw that the light was good and he separated the light from the darkness,",
      chunks[3].to_s
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks[3].status
    assert_in_delta 0.93, chunks[3].confidence, 0.01
    assert_equal 16, chunks[3].words.size

    #5
    assert_equal 5, chunks[4].position
    assert_equal 24.58, chunks[4].start_time
    assert_equal 33.69, chunks[4].end_time
    assert_equal 9.11, chunks[4].duration
    assert_equal "God called the light day of the darkness he called night. and There was evening and there was morning the first thing",
      chunks[4].to_s
    assert_equal CPW::Speech::AudioChunk::STATUS_TRANSCRIBED, chunks[4].status
    assert_in_delta 0.90, chunks[4].confidence, 0.01
    assert_equal 23, chunks[4].words.size
  end

  def test_words_to_json
    engine     = new_engine
    chunks     = engine.perform(basefolder: "/tmp")
    words_json = '[{"p":1,"c":0.815,"s":0.309,"e":0.888,"w":"in"},{"p":2,"c":0.675,"s":0.888,"e":0.967,"w":"the"},{"p":3,"c":0.26,"s":0.967,"e":1.347,"w":"beginning"},{"p":4,"c":0.127,"s":1.347,"e":1.606,"w":"got"},{"p":5,"c":0.234,"s":1.606,"e":1.885,"w":"screwed"},{"p":6,"c":0.138,"s":1.885,"e":1.945,"w":"in"},{"p":7,"c":0.543,"s":1.945,"e":2.045,"w":"the"},{"p":8,"c":0.494,"s":2.045,"e":2.404,"w":"heavens"},{"p":9,"c":0.836,"s":2.404,"e":2.524,"w":"of"},{"p":10,"c":0.91,"s":2.524,"e":2.644,"w":"the"},{"p":11,"c":0.696,"s":2.644,"e":3.601,"w":"art"},{"p":12,"c":0.788,"s":3.601,"e":3.861,"w":"now"},{"p":13,"c":0.856,"s":3.861,"e":4.04,"w":"the"},{"p":14,"c":0.941,"s":4.04,"e":4.4,"w":"earth"},{"p":15,"c":0.981,"s":4.4,"e":4.599,"w":"was"},{"p":16,"c":0.982,"s":4.599,"e":5.337,"w":"formless"},{"p":17,"c":0.978,"s":5.337,"e":5.497,"w":"and"},{"p":18,"c":0.983,"s":5.497,"e":6.634,"w":"empty"},{"p":19,"c":65.535,"s":6.634,"e":6.644,"w":","}]'
    assert_equal words_json, chunks[0].words.to_json
  end

  protected

  def new_engine(options = {})
    media_file = File.join(fixtures_root, "i-like-pickles.wav")

    # upload_media (with file)
    stub_request(:post, "https://api.voicebase.com/services").
      with(:headers => {'Accept'=>'application/json', 'Content-Length'=>'226171', 'Content-Type'=>'multipart/form-data; boundary=-----------RubyMultipartPost'}).
      to_return(:status => 200,
        :body => '{"requestStatus":"SUCCESS","statusMessage":"The request was processed successfully","mediaId":"569e7fe9092a6","externalId":"abcd1234","fileUrl":"http:\/\/www.voicebase.com\/autonotes\/private_detail\/14167302\/hash=apiWZmtoZmqWbGydx2iXnXGSb2qWlw=="}',
        :headers => {
          "content-type"=>["application/json; charset=utf-8"]
        })

    # get_file_status (media_id)
    stub_request(:post, "https://api.voicebase.com/services").
      with(:body => "version=1.1&apiKey=opqrst&password=uvwxyz&lang=en&mediaID=569e7fe9092a6&action=getFileStatus",
        :headers => {'Accept'=>'application/json'}).
      to_return(:status => 200,
        :body => '{"requestStatus":"SUCCESS","statusMessage":"The request was processed successfully","fileStatus":"MACHINECOMPLETE","response":"Transcribed"}',
        :headers => {
          "content-type"=>["application/json; charset=utf-8"]
        })

    # get_file_status (external_id)
    stub_request(:post, "https://api.voicebase.com/services").
      with(:body => "version=1.1&apiKey=opqrst&password=uvwxyz&lang=en&externalID=abcd1234&action=getFileStatus",
        :headers => {'Accept'=>'application/json'}).
      to_return(:status => 200,
        :body => '{"requestStatus":"SUCCESS","statusMessage":"The request was processed successfully","fileStatus":"MACHINECOMPLETE","response":"Transcribed"}',
        :headers => {
          "content-type"=>["application/json; charset=utf-8"]
        })

    # get_transcript (srt)
    stub_request(:post, "https://api.voicebase.com/services").
      #with(:body => "version=1.1&apiKey=opqrst&password=uvwxyz&lang=en&mediaID=569e7fe9092a6&format=srt&action=getTranscript",
      with(:body => "version=1.1&apiKey=opqrst&password=uvwxyz&lang=en&format=srt&externalID=abcd1234&action=getTranscript",
        :headers => {'Accept'=>'application/json'}).
      to_return(:status => 200,
        :body => '{"requestStatus":"SUCCESS","statusMessage":"The request was processed successfully","transcript":"1\n00:00:00,31 --> 00:00:06,64\nIn the beginning got screwed in the heavens of the art now the earth was formless and empty,\n\n2\n00:00:06,64 --> 00:00:13,67\ndarkness was over the surface of the deep of the Spirit of God was hovering over the waters.\n\n3\n00:00:13,67 --> 00:00:18,78\nand God said let there be light and there was light.\n\n4\n00:00:18,78 --> 00:00:24,58\nGod saw that the light was good and he separated the light from the darkness,\n\n5\n00:00:24,58 --> 00:00:33,69\nGod called the light day of the darkness he called night. and There was evening and there was morning the first thing\n\n","transcriptType":"machine"}',
        :headers => {
          "content-type"=>["application/json; charset=utf-8"]
        })

    # get_transcript (json)
    stub_request(:post, "https://api.voicebase.com/services").
      with(:body => "version=1.1&apiKey=opqrst&password=uvwxyz&lang=en&format=json&externalID=abcd1234&action=getTranscript",
        :headers => {'Accept'=>'application/json'}).
      to_return(:status => 200,
        :body => '{"requestStatus":"SUCCESS","statusMessage":"The request was processed successfully","transcript":"[{\"p\":1,\"c\":0.815,\"s\":309,\"e\":888,\"w\":\"in\"},{\"p\":2,\"c\":0.675,\"s\":888,\"e\":967,\"w\":\"the\"},{\"p\":3,\"c\":0.26,\"s\":967,\"e\":1347,\"w\":\"beginning\"},{\"p\":4,\"c\":0.127,\"s\":1347,\"e\":1606,\"w\":\"got\"},{\"p\":5,\"c\":0.234,\"s\":1606,\"e\":1885,\"w\":\"screwed\"},{\"p\":6,\"c\":0.138,\"s\":1885,\"e\":1945,\"w\":\"in\"},{\"p\":7,\"c\":0.543,\"s\":1945,\"e\":2045,\"w\":\"the\"},{\"p\":8,\"c\":0.494,\"s\":2045,\"e\":2404,\"w\":\"heavens\"},{\"p\":9,\"c\":0.836,\"s\":2404,\"e\":2524,\"w\":\"of\"},{\"p\":10,\"c\":0.91,\"s\":2524,\"e\":2644,\"w\":\"the\"},{\"p\":11,\"c\":0.696,\"s\":2644,\"e\":3601,\"w\":\"art\"},{\"p\":12,\"c\":0.788,\"s\":3601,\"e\":3861,\"w\":\"now\"},{\"p\":13,\"c\":0.856,\"s\":3861,\"e\":4040,\"w\":\"the\"},{\"p\":14,\"c\":0.941,\"s\":4040,\"e\":4400,\"w\":\"earth\"},{\"p\":15,\"c\":0.981,\"s\":4400,\"e\":4599,\"w\":\"was\"},{\"p\":16,\"c\":0.982,\"s\":4599,\"e\":5337,\"w\":\"formless\"},{\"p\":17,\"c\":0.978,\"s\":5337,\"e\":5497,\"w\":\"and\"},{\"p\":18,\"c\":0.983,\"s\":5497,\"e\":6634,\"w\":\"empty\"},{\"p\":19,\"c\":65.535,\"s\":6634,\"e\":6644,\"w\":\",\",\"m\":\"punc\"},{\"p\":20,\"c\":0.977,\"s\":6644,\"e\":7273,\"w\":\"darkness\"},{\"p\":21,\"c\":0.976,\"s\":7273,\"e\":7532,\"w\":\"was\"},{\"p\":22,\"c\":0.977,\"s\":7532,\"e\":7732,\"w\":\"over\"},{\"p\":23,\"c\":0.985,\"s\":7732,\"e\":7832,\"w\":\"the\"},{\"p\":24,\"c\":0.987,\"s\":7832,\"e\":8450,\"w\":\"surface\"},{\"p\":25,\"c\":0.978,\"s\":8450,\"e\":8630,\"w\":\"of\"},{\"p\":26,\"c\":0.951,\"s\":8630,\"e\":8690,\"w\":\"the\"},{\"p\":27,\"c\":0.934,\"s\":8690,\"e\":9667,\"w\":\"deep\"},{\"p\":28,\"c\":0.892,\"s\":9667,\"e\":9847,\"w\":\"of\"},{\"p\":29,\"c\":0.915,\"s\":9847,\"e\":9927,\"w\":\"the\"},{\"p\":30,\"c\":0.853,\"s\":9927,\"e\":10505,\"w\":\"Spirit\"},{\"p\":31,\"c\":0.96,\"s\":10505,\"e\":10665,\"w\":\"of\"},{\"p\":32,\"c\":0.957,\"s\":10665,\"e\":11084,\"w\":\"God\"},{\"p\":33,\"c\":0.955,\"s\":11084,\"e\":11244,\"w\":\"was\"},{\"p\":34,\"c\":0.978,\"s\":11244,\"e\":11822,\"w\":\"hovering\"},{\"p\":35,\"c\":0.977,\"s\":11822,\"e\":12062,\"w\":\"over\"},{\"p\":36,\"c\":0.971,\"s\":12062,\"e\":12162,\"w\":\"the\"},{\"p\":37,\"c\":0.966,\"s\":12162,\"e\":13519,\"w\":\"waters\"},{\"p\":38,\"c\":65.535,\"s\":13659,\"e\":13669,\"w\":\".\",\"m\":\"punc\"},{\"p\":39,\"c\":0.948,\"s\":13669,\"e\":13858,\"w\":\"and\"},{\"p\":40,\"c\":0.969,\"s\":13858,\"e\":14297,\"w\":\"God\"},{\"p\":41,\"c\":0.961,\"s\":14297,\"e\":15315,\"w\":\"said\"},{\"p\":42,\"c\":0.972,\"s\":15315,\"e\":15734,\"w\":\"let\"},{\"p\":43,\"c\":0.976,\"s\":15734,\"e\":15993,\"w\":\"there\"},{\"p\":44,\"c\":0.983,\"s\":15993,\"e\":16113,\"w\":\"be\"},{\"p\":45,\"c\":0.976,\"s\":16113,\"e\":17111,\"w\":\"light\"},{\"p\":46,\"c\":0.952,\"s\":17111,\"e\":17330,\"w\":\"and\"},{\"p\":47,\"c\":0.937,\"s\":17330,\"e\":17490,\"w\":\"there\"},{\"p\":48,\"c\":0.912,\"s\":17490,\"e\":17669,\"w\":\"was\"},{\"p\":49,\"c\":0.861,\"s\":17669,\"e\":18727,\"w\":\"light\"},{\"p\":50,\"c\":65.535,\"s\":18767,\"e\":18777,\"w\":\".\",\"m\":\"punc\"},{\"p\":51,\"c\":0.89,\"s\":18777,\"e\":19186,\"w\":\"God\"},{\"p\":52,\"c\":0.917,\"s\":19186,\"e\":19765,\"w\":\"saw\"},{\"p\":53,\"c\":0.931,\"s\":19765,\"e\":19944,\"w\":\"that\"},{\"p\":54,\"c\":0.943,\"s\":19944,\"e\":20024,\"w\":\"the\"},{\"p\":55,\"c\":0.944,\"s\":20024,\"e\":20443,\"w\":\"light\"},{\"p\":56,\"c\":0.951,\"s\":20443,\"e\":20662,\"w\":\"was\"},{\"p\":57,\"c\":0.961,\"s\":20662,\"e\":21521,\"w\":\"good\"},{\"p\":58,\"c\":0.928,\"s\":21521,\"e\":21780,\"w\":\"and\"},{\"p\":59,\"c\":0.911,\"s\":21780,\"e\":21960,\"w\":\"he\"},{\"p\":60,\"c\":0.916,\"s\":21960,\"e\":22618,\"w\":\"separated\"},{\"p\":61,\"c\":0.952,\"s\":22618,\"e\":22678,\"w\":\"the\"},{\"p\":62,\"c\":0.959,\"s\":22678,\"e\":22977,\"w\":\"light\"},{\"p\":63,\"c\":0.966,\"s\":22977,\"e\":23197,\"w\":\"from\"},{\"p\":64,\"c\":0.964,\"s\":23197,\"e\":23257,\"w\":\"the\"},{\"p\":65,\"c\":0.938,\"s\":23257,\"e\":24573,\"w\":\"darkness\"},{\"p\":66,\"c\":65.535,\"s\":24573,\"e\":24583,\"w\":\",\",\"m\":\"punc\"},{\"p\":67,\"c\":0.88,\"s\":24583,\"e\":24893,\"w\":\"God\"},{\"p\":68,\"c\":0.881,\"s\":24893,\"e\":25252,\"w\":\"called\"},{\"p\":69,\"c\":0.922,\"s\":25252,\"e\":25312,\"w\":\"the\"},{\"p\":70,\"c\":0.929,\"s\":25312,\"e\":25930,\"w\":\"light\"},{\"p\":71,\"c\":0.939,\"s\":25930,\"e\":26808,\"w\":\"day\"},{\"p\":72,\"c\":0.688,\"s\":26808,\"e\":26968,\"w\":\"of\"},{\"p\":73,\"c\":0.751,\"s\":26968,\"e\":27048,\"w\":\"the\"},{\"p\":74,\"c\":0.739,\"s\":27048,\"e\":27666,\"w\":\"darkness\"},{\"p\":75,\"c\":0.879,\"s\":27666,\"e\":27746,\"w\":\"he\"},{\"p\":76,\"c\":0.987,\"s\":27746,\"e\":28385,\"w\":\"called\"},{\"p\":77,\"c\":0.981,\"s\":28385,\"e\":29462,\"w\":\"night\"},{\"p\":78,\"c\":65.535,\"s\":29462,\"e\":29472,\"w\":\".\",\"m\":\"punc\"},{\"p\":79,\"c\":0.952,\"s\":29472,\"e\":29742,\"w\":\"and\"},{\"p\":80,\"c\":0.888,\"s\":29742,\"e\":29861,\"w\":\"there\"},{\"p\":81,\"c\":0.945,\"s\":29861,\"e\":30121,\"w\":\"was\"},{\"p\":82,\"c\":0.972,\"s\":30121,\"e\":31158,\"w\":\"evening\"},{\"p\":83,\"c\":0.978,\"s\":31158,\"e\":31498,\"w\":\"and\"},{\"p\":84,\"c\":0.966,\"s\":31498,\"e\":31617,\"w\":\"there\"},{\"p\":85,\"c\":0.974,\"s\":31617,\"e\":31817,\"w\":\"was\"},{\"p\":86,\"c\":0.972,\"s\":31817,\"e\":32435,\"w\":\"morning\"},{\"p\":87,\"c\":0.966,\"s\":32435,\"e\":32555,\"w\":\"the\"},{\"p\":88,\"c\":0.96,\"s\":32555,\"e\":33014,\"w\":\"first\"},{\"p\":89,\"c\":0.788,\"s\":33014,\"e\":33692,\"w\":\"thing\"}]","transcriptType":"machine"}',
        :headers => {
          "content-type"=>["application/json; charset=utf-8"]
        })

    CPW::Speech::Engines::VoicebaseEngine.new(media_file, {
      api_version: "1.1",
      transcription_type: "machine",
      auth_key: "opqrst",
      auth_secret: "uvwxyz",
      external_id: "abcd1234"
    }.merge(options))
  end
end
