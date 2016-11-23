require 'test_helper.rb'

class CPW::Speech::Engines::VoicebaseEngine::WordsTest < Test::Unit::TestCase
  def setup
    @words_json = '[{"p":1,"c":0.7,"s":1610,"e":1780,"w":"This"},{"p":2,"c":0.714,"s":1780,"e":1960,"w":"is"},{"p":3,"c":0.502,"s":1960,"e":2440,"w":"Tom"},{"p":4,"c":0.506,"s":2440,"e":2960,"w":"Cook"},{"p":5,"c":0.501,"s":2960,"e":3200,"w":"car"},{"p":6,"c":0.51,"s":3200,"e":3340,"w":"team"},{"p":7,"c":0,"s":3340,"e":3560,"w":".","m":"punc"},{"p":8,"c":0.589,"s":3560,"e":3800,"w":"This"},{"p":9,"c":0.733,"s":3800,"e":3860,"w":"is"},{"p":10,"c":0.731,"s":3860,"e":4300,"w":"a"},{"p":11,"c":0.511,"s":4300,"e":4450,"w":"production"},{"p":12,"c":0,"s":4450,"e":5140,"w":".","m":"punc"},{"p":13,"c":0.501,"s":5140,"e":5510,"w":"Verification"},{"p":14,"c":0.53,"s":5510,"e":5590,"w":"video"},{"p":15,"c":0.783,"s":5590,"e":5959,"w":"of"},{"p":16,"c":0.749,"s":5960,"e":6310,"w":"a"},{"p":17,"c":0.813,"s":6310,"e":6580,"w":"new"},{"p":18,"c":0.54,"s":6580,"e":7370,"w":"feature"},{"p":19,"c":0,"s":7370,"e":8120,"w":".","m":"punc"},{"p":20,"c":0.774,"s":8120,"e":8480,"w":"The"},{"p":21,"c":0.529,"s":8480,"e":8709,"w":"future"},{"p":22,"c":0.789,"s":8710,"e":9290,"w":"is"},{"p":23,"c":0.501,"s":9290,"e":9730,"w":"direct"},{"p":24,"c":0.538,"s":9730,"e":10240,"w":"video"},{"p":25,"c":0.501,"s":10240,"e":10460,"w":"uploads"},{"p":26,"c":0.803,"s":10460,"e":10670,"w":"to"},{"p":27,"c":0.501,"s":10670,"e":10790,"w":"S"},{"p":28,"c":0.782,"s":10790,"e":11300,"w":"three"},{"p":29,"c":0.68,"s":11300,"e":11790,"w":"from"},{"p":30,"c":0.505,"s":11790,"e":12080,"w":"Android"},{"p":31,"c":0.685,"s":12080,"e":12910,"w":"devices"},{"p":32,"c":0,"s":12910,"e":13560,"w":".","m":"punc"},{"p":33,"c":0.517,"s":13590,"e":13760,"w":"If"},{"p":34,"c":0.735,"s":13760,"e":14110,"w":"this"},{"p":35,"c":0.709,"s":14110,"e":14470,"w":"video"},{"p":36,"c":0.517,"s":14470,"e":15079,"w":"upload"},{"p":37,"c":0.501,"s":15080,"e":15250,"w":"successful"},{"p":38,"c":0.523,"s":15250,"e":15340,"w":"even"},{"p":39,"c":0.579,"s":15340,"e":15650,"w":"I"},{"p":40,"c":0.844,"s":15650,"e":15800,"w":"believe"},{"p":41,"c":0.801,"s":15800,"e":16180,"w":"this"},{"p":42,"c":0.508,"s":16180,"e":16210,"w":"test"},{"p":43,"c":0.755,"s":16210,"e":16960,"w":"is"},{"p":44,"c":0.539,"s":16960,"e":17620,"w":"complete"},{"p":45,"c":1,"s":17620,"e":18170,"w":"and"},{"p":46,"c":0.769,"s":18170,"e":18440,"w":"the"},{"p":47,"c":0.504,"s":18440,"e":18530,"w":"feature"},{"p":48,"c":0.754,"s":18530,"e":18950,"w":"is"},{"p":49,"c":0.505,"s":18950,"e":19710,"w":"verified"},{"p":50,"c":0,"s":19710,"e":19710,"w":".","m":"punc"}]'
    @words = CPW::Speech::Engines::VoicebaseEngine::Words.parse(@words_json)
  end

  # instance methods

  def test_parses_from_string
    assert_equal 50, @words.length

    # 1
    assert_equal 1, @words[0].position
    assert_equal "This", @words[0].word
    assert_equal 0.7, @words[0].confidence
    assert_equal 1.61, @words[0].start_time
    assert_equal 1.78, @words[0].end_time
    assert_equal (1.78 - 1.61), @words[0].duration

    # 2
    assert_equal 2, @words[1].position
    assert_equal "is", @words[1].word
    assert_equal 0.714, @words[1].confidence
    assert_equal 1.78, @words[1].start_time
    assert_equal 1.96, @words[1].end_time
    assert_equal (1.96 - 1.78), @words[1].duration

    # 3
    assert_equal 3, @words[2].position
    assert_equal "Tom", @words[2].word
    assert_equal 0.502, @words[2].confidence
    assert_equal 1.96, @words[2].start_time
    assert_equal 2.44, @words[2].end_time
    assert_equal (2.44 - 1.96), @words[2].duration
  end

  def test_to_s
    assert_equal "This is Tom Cook car team. This is a production. Verification video of a new feature. The future is direct video uploads to S three from Android devices. If this video upload successful even I believe this test is complete and the feature is verified.",
      @words.to_s
  end

  def test_to_json
    assert_equal '[{"p":1,"c":0.7,"s":1.61,"e":1.78,"w":"This"}]',
      @words.from(1.610).to(1.780).to_json
  end

  def test_to_voicebase_json
    assert_equal '[{"p":1,"c":0.7,"s":1610,"e":1780,"w":"This"}]',
      @words.from(1.610).to(1.780).to_json(:voicebase)
  end

  # scopes

  def test_chain_from_and_to_scopes
    assert_equal @words.first, @words.from(1.610).to(1.780).first
  end

end
