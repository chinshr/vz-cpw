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

  def test_should_split_audio_into_flac_chunks
    splitter = CPW::Speech::AudioSplitter.new(@short_wav_file)

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status  # built because there is only one chunk
      chunk.build
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status
      chunk.to_flac
      assert_equal CPW::Speech::AudioChunk::STATUS_ENCODED, chunk.status
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
    splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'))

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status  # built because there is only one chunk
      chunk.build
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status
      chunk.to_wav
      assert_equal CPW::Speech::AudioChunk::STATUS_ENCODED, chunk.status
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
    splitter = CPW::Speech::AudioSplitter.new(File.join(fixtures_root, 'i-like-pickles.wav'))

    assert_equal '00:00:03.52', splitter.duration.to_s
    assert_equal 3.52, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 1, chunks.size
    chunks.each do|chunk|
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status  # built because there is only one chunk
      chunk.build
      assert_equal CPW::Speech::AudioChunk::STATUS_BUILT, chunk.status
      chunk.to_raw
      assert_equal CPW::Speech::AudioChunk::STATUS_ENCODED, chunk.status
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
    splitter = CPW::Speech::AudioSplitter.new(@long_wav_file)

    assert_equal '00:00:54.10', splitter.duration.to_s
    assert_equal 54.1, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 10, chunks.size
    assert_equal true, chunks.all? {|ch| ch.status == CPW::Speech::AudioChunk::STATUS_UNPROCESSED}
    assert_equal 5, chunks.first.duration
    assert_equal 9.1, chunks.last.duration
  end

  # diarize

  def test_should_diarize_locally
    splitter = CPW::Speech::AudioSplitter.new(@long_wav_file, {:split_method => :diarize})
    assert_equal :diarize, splitter.split_method
    assert_equal '00:00:54.10', splitter.duration.to_s
    assert_equal 54.1, splitter.duration.to_f

    chunks = splitter.split
    assert_equal 5, chunks.size
    assert_equal true, chunks.all? {|ch| ch.status == CPW::Speech::AudioChunk::STATUS_UNPROCESSED}

    assert_equal 1, chunks[0].id
    assert_in_delta 0.0, chunks[0].offset, 0.01
    assert_in_delta 2.5, chunks[0].duration, 0.01
    assert_equal "U", chunks[0].bandwidth
    assert chunks[0].speaker
    assert_equal "M", chunks[0].speaker.gender

    assert_equal 2, chunks[1].id
    assert_in_delta 2.5, chunks[1].offset, 0.01
    assert_in_delta 17.23, chunks[1].duration, 0.01
    assert_equal "U", chunks[1].bandwidth
    assert chunks[1].speaker
    assert_equal "M", chunks[1].speaker.gender

    assert_equal 3, chunks[2].id
    assert_in_delta 19.75, chunks[2].offset, 0.01
    assert_in_delta 13.63, chunks[2].duration, 0.01
    assert_equal "U", chunks[2].bandwidth
    assert chunks[2].speaker
    assert_equal "M", chunks[2].speaker.gender

    assert_equal 4, chunks[3].id
    assert_in_delta 33.63, chunks[3].offset, 0.01
    assert_in_delta 14.59, chunks[3].duration, 0.01
    assert_equal "U", chunks[3].bandwidth
    assert chunks[3].speaker
    assert_equal "M", chunks[3].speaker.gender

    assert_equal 5, chunks[4].id
    assert_in_delta 48.22, chunks[4].offset, 0.01
    assert_in_delta 5.86, chunks[4].duration, 0.01
    assert_equal "U", chunks[4].bandwidth
    assert chunks[4].speaker
    assert_equal "M", chunks[4].speaker.gender
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
