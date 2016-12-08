require 'test_helper.rb'

class CPW::Speech::AudioSplitterTest < Test::Unit::TestCase
  def setup
    @short_wav_file = File.join(fixtures_root, 'i-like-pickles.wav')
    @long_wav_file  = File.join(fixtures_root, 'will-and-juergen.wav')
  end

  def test_default_settings
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file)
    assert_equal [], splitter.chunks
    assert_equal nil, splitter.basefolder
    assert_equal nil, splitter.engine
    assert_equal false, splitter.verbose
    assert_equal CPW::logger, splitter.logger
    assert_equal :auto, splitter.split_method
    assert_equal({}, splitter.split_options)
  end

  def test_basefolder
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {:basefolder => "/tmp"})
    assert_equal "/tmp", splitter.basefolder
  end

  def test_chunk_duration
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {:chunk_duration => 11})
    assert_equal 11, splitter.chunk_duration

    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {:chunk_duration => nil})
    assert_equal 5, splitter.chunk_duration
  end

  def test_verbose
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {:verbose => true})
    assert_equal true, splitter.verbose
  end

  def test_split_method
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file)
    assert_equal :auto, splitter.split_method

    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {:split_method => :basic})
    assert_equal :basic, splitter.split_method
  end

  def test_split_options
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file,
      {:split_options => {:mode => :druby, :host => "drb.example.com", :port => 1234}})
    assert_equal :druby, splitter.split_options[:mode]
    assert_equal "drb.example.com", splitter.split_options[:host]
    assert_equal 1234, splitter.split_options[:port]
  end

  def test_raise_invalid_split_method_error_with_invalid_split_method
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {split_method: :foobar})
    assert_raise CPW::Speech::InvalidSplitMethod do
      splitter.split
    end
  end

  def test_raise_invalid_split_method_error_with_auto_and_without_engine
    engine = CPW::Speech::Engines::SpeechEngine.new(@short_wav_file)
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {engine: engine})
    assert_raise CPW::Speech::InvalidSplitMethod do
      splitter.split
    end
  end

  def test_should_split_audio_into_flac_chunks
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {split_method: :basic})

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f
    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal true, chunk.built?  # built because there is only one chunk
      chunk.build
      assert_equal true, chunk.built?
      chunk.to_flac
      assert_equal true, chunk.encoded?
      assert chunk.to_flac_bytes
      assert_equal 46385, chunk.flac_size

      assert_equal [], chunk.errors
      assert File.exist? chunk.chunk
      assert File.exist? chunk.flac_chunk
      chunk.clean
      assert !File.exist?(chunk.chunk)
      assert !File.exist?(chunk.flac_chunk)
    end
  end

  def test_should_split_audio_into_wav_chunks
    splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'), {split_method: :basic})

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal true, chunk.built?
      chunk.build
      assert_equal true, chunk.built?
      chunk.to_wav
      assert_equal true, chunk.encoded?
      assert chunk.to_wav_bytes
      assert_equal 112698, chunk.wav_size

      assert_equal [], chunk.errors
      assert File.exist? chunk.chunk
      assert File.exist? chunk.wav_chunk
      chunk.clean
      assert !File.exist?(chunk.chunk)
      assert !File.exist?(chunk.wav_chunk)
    end
  end

  def test_should_split_audio_into_raw_chunks
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file, {split_method: :basic})

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal true, chunk.built?  # built because there is only one chunk
      chunk.build
      assert_equal true, chunk.built?
      chunk.to_raw
      assert_equal true, chunk.encoded?
      assert chunk.to_raw_bytes
      assert_equal 112620, chunk.raw_size

      assert_equal [], chunk.errors
      assert File.exist? chunk.chunk
      assert File.exist? chunk.raw_chunk
      chunk.clean
      assert !File.exist?(chunk.chunk)
      assert !File.exist?(chunk.raw_chunk)
    end
  end

  def test_should_use_basic_splitter_with_long_file
    splitter = CPW::Speech::AudioSplitter.new(@long_wav_file, {split_method: :basic})

    assert_equal '00:00:54.10', splitter.duration.to_s
    assert_equal 54.1, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 10, chunks.size
    assert_equal true, chunks.all? {|ch| ch.status == CPW::Speech::STATUS_UNPROCESSED}
    assert_equal 5, chunks.first.duration
    assert_equal 9.1, chunks.last.duration
  end

  # diarize

  def test_should_diarize_local
    splitter = CPW::Speech::AudioSplitter.new(@long_wav_file, {
      :split_method => :diarize,
      :split_options => {
        :model_base_url => "http://www.example.com",
        :model_base_name => "xyz"
      }
    })
    assert_equal :diarize, splitter.split_method
    assert_equal '00:00:54.10', splitter.duration.to_s
    assert_equal 54.1, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 5, chunks.size
    assert_equal true, chunks.all? {|ch| ch.status == CPW::Speech::STATUS_UNPROCESSED}

    # chunk 1
    assert_equal 1, chunks[0].position
    assert_equal 1, chunks[0].id
    assert_in_delta 0.0, chunks[0].offset, 0.01
    assert_in_delta 2.5, chunks[0].duration, 0.01
    assert chunks[0].speaker_segment
    assert_equal "M", chunks[0].speaker_segment.speaker_gender
    assert_equal "S0", chunks[0].speaker_segment.speaker_id
    assert chunks[0].speaker
    assert_equal "M", chunks[0].speaker.gender
    assert_equal "http://www.example.com/xyz-S0.gmm", chunks[0].speaker.model_uri
    assert_not_nil chunks[0].as_json['speaker_segment']['speaker_supervector_hash']

    # chunk 2
    assert_equal 2, chunks[1].position
    assert_equal 2, chunks[1].id
    assert_in_delta 2.5, chunks[1].offset, 0.01
    assert_in_delta 17.23, chunks[1].duration, 0.01
    assert chunks[1].speaker_segment
    assert_equal "M", chunks[1].speaker_segment.speaker_gender
    assert_equal "S1", chunks[1].speaker_segment.speaker_id
    assert chunks[1].speaker
    assert_equal "M", chunks[1].speaker.gender
    assert_equal "http://www.example.com/xyz-S1.gmm", chunks[1].speaker.model_uri
    assert_not_nil chunks[1].as_json['speaker_segment']['speaker_supervector_hash']

    # chunk 3
    assert_equal 3, chunks[2].position
    assert_equal 3, chunks[2].id
    assert_in_delta 19.75, chunks[2].offset, 0.01
    assert_in_delta 13.63, chunks[2].duration, 0.01
    assert chunks[2].speaker_segment
    assert_equal "M", chunks[2].speaker_segment.speaker_gender
    assert_equal "S3", chunks[2].speaker_segment.speaker_id
    assert chunks[2].speaker
    assert_equal "M", chunks[2].speaker.gender
    assert_equal "http://www.example.com/xyz-S3.gmm", chunks[2].speaker.model_uri
    assert_not_nil chunks[2].as_json['speaker_segment']['speaker_supervector_hash']

    # chunk 4
    assert_equal 4, chunks[3].position
    assert_equal 4, chunks[3].id
    assert_in_delta 33.63, chunks[3].offset, 0.01
    assert_in_delta 14.59, chunks[3].duration, 0.01
    assert chunks[3].speaker_segment
    assert_equal "M", chunks[3].speaker_segment.speaker_gender
    assert_equal "S5", chunks[3].speaker_segment.speaker_id
    assert chunks[3].speaker
    assert_equal "M", chunks[3].speaker.gender
    assert_equal "http://www.example.com/xyz-S5.gmm", chunks[3].speaker.model_uri
    assert_not_nil chunks[3].as_json['speaker_segment']['speaker_supervector_hash']

    # chunk 5
    assert_equal 5, chunks[4].position
    assert_equal 5, chunks[4].id
    assert_in_delta 48.22, chunks[4].offset, 0.01
    assert_in_delta 5.86, chunks[4].duration, 0.01
    assert chunks[4].speaker_segment
    assert_equal "M", chunks[4].speaker_segment.speaker_gender
    assert_equal "S5", chunks[4].speaker_segment.speaker_id
    assert chunks[4].speaker
    assert_equal "M", chunks[4].speaker.gender
    assert_equal "http://www.example.com/xyz-S5.gmm", chunks[4].speaker.model_uri
    assert_not_nil chunks[4].as_json['speaker_segment']['speaker_supervector_hash']
  end

  def xtest_should_diarize_remote
    splitter = CPW::Speech::AudioSplitter.new(@long_wav_file,
      {:split_method => :diarize, :split_options => {:mode => :druby, :port => 9998, :host => "localhost"}})
    assert_equal :diarize, splitter.split_method

    omit "fork process in test not working."

    # start server
    pid = Process.fork do
      Signal.trap("QUIT") { DRb.stop_service; exit }
      uri = "druby://#{'localhost'}:#{9998}"
      server = Diarize::Server.new
      DRb.start_service(uri, server)
      DRb.thread.join
    end

    chunks = splitter.split
    assert_equal 5, chunks.size

    Process.kill("QUIT", pid)
    Process.wait
  end
end
