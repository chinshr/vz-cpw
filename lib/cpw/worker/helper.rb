module CPW::Worker::Helper

  # -------------------------------------------------------------
  # file + file name helpers
  # -------------------------------------------------------------

  def basefolder(uid = nil, stage = nil)
    File.join("/tmp", (uid || @ingest.uid), (stage || self.class.stage_name))
  end

  def expand_fullpath_name(file_name, uid = nil, stage = nil)
    File.join(basefolder(uid, stage), file_name)
  end

  # replace_file_extension("test.128Kb.mp3", ".wav") -> "test.128Kb.wav"
  def replace_file_extension(file_name, new_extension)
    file_name.gsub(/#{File.extname(file_name)}$/, new_extension)
  end

  # key is "<folder>/<file>"
  def original_media_file
    # @ingest.track.s3_key.split("/").last if @ingest && @ingest.track
    @ingest.s3_origin_key.split("/").last if @ingest
  end

  def original_media_key
    # @ingest.track.s3_key if @ingest && @ingest.track
    @ingest.s3_origin_key if @ingest
  end

  def original_media_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), original_media_file) if original_media_file
  end

  def single_channel_wav_audio_file
    "#{original_media_file}.ac1.wav" if @ingest
  end

  def single_channel_wav_audio_key
    "#{original_media_key}.ac1.wav" if @ingest
  end

  def single_channel_wav_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), single_channel_wav_audio_file) if single_channel_wav_audio_file
  end

  def dual_channel_wav_audio_file
    "#{original_media_file}.ac2.wav" if @ingest
  end

  def dual_channel_wav_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), dual_channel_wav_audio_file) if dual_channel_wav_audio_file
  end

  def normalized_audio_file
    "#{original_media_file}.ac1.normalized.wav" if @ingest
  end

  def normalized_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), normalized_audio_file) if normalized_audio_file
  end

  def noise_reduced_wav_audio_file
    "#{original_media_file}.ac1.normalized.noise-reduced.wav" if @ingest
  end

  def noise_reduced_wav_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), noise_reduced_wav_audio_file) if noise_reduced_wav_audio_file
  end

  def mp3_audio_file
    @ingest.s3_origin_mp3_key.split("/").last if @ingest
  end

  def mp3_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), mp3_audio_file) if mp3_audio_file
  end

  def waveform_json_file
    @ingest.s3_origin_waveform_json_key.split("/").last if @ingest
  end

  def waveform_json_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), waveform_json_file) if waveform_json_file
  end

  def pcm_audio_file
    endianness = system_endianness
    "#{original_media_file}.ac1.ar16k.#{endianness}.pcm" if @ingest
  end

  def pcm_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), pcm_audio_file) if pcm_audio_file
  end

  def subtitle_file
    ingest.s3_origin_subtitle_key.split("/").last if ingest && ingest.s3_origin_subtitle_key
  end

  def subtitle_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), subtitle_file) if subtitle_file
  end

  # -------------------------------------------------------------
  # S3
  # -------------------------------------------------------------

  def s3_origin_bucket_name
    ENV['S3_OUTBOUND_BUCKET']
  end

  def s3_origin_uri(file_name)
    File.join(self.s3_origin_bucket_name, file_name)
  end

  def s3_key_for(file_name)
    if @ingest && @ingest.track && @ingest.track.s3_key
      key = @ingest.track.s3_key
      folder = key.split("/").size > 1 ? key.split("/").slice(0...-1) : ""
      File.join(folder, file_name)
    else
      File.join(@ingest.uid, file_name)
    end
  end

  def s3_origin_url_for(file_name)
    File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_key_for(file_name))
  end

  def s3_copy_object(source_bucket_name, destination_bucket_name, source_key, destination_key = nil)
    s3 = AWS::S3.new
    destination_key = source_key if destination_key.blank?
    s3.buckets[source_bucket_name].objects[source_key].copy_to(destination_key, :bucket_name => destination_bucket_name)
  end

  def s3_download_object(source_bucket_name, source_key, destination_filename)
    CPW::logger.info "-->> S3 download : #{source_bucket_name}, #{source_key}, #{destination_filename}"
    # create directory if not exists
    FileUtils::mkdir_p "/#{File.join(destination_filename.split("/").slice(1...-1))}"
    # download to folder
    s3 = AWS::S3.new
    File.open(destination_filename, 'wb') do |file|
      s3.buckets[source_bucket_name].objects[source_key].read do |chunk|
        file.write(chunk)
      end
    end
  end

  def s3_copy_object_if_exists(source_bucket_name, source_key, destination_bucket_name, destination_key = nil)
    s3 = AWS::S3.new
    result = false
    destination_key = source_key if destination_key.nil?
    if s3.buckets[source_bucket_name].objects[source_key].exists?
      s3.buckets[source_bucket_name].objects[source_key].copy_to(destination_key, :bucket_name => destination_bucket_name)
      result = true
    end
    result
  end

  def s3_delete_object(bucket_name, key)
    s3 = AWS::S3.new
    s3.buckets[bucket_name].objects.delete(key)
  end

  def s3_delete_object_if_exists(bucket_name, key)
    s3 = AWS::S3.new
    result = false
    if bucket_name.present? && key.present? && s3.buckets[bucket_name].objects[key].exists?
      s3.buckets[bucket_name].objects.delete(key)
      result = true
    end
    result
  rescue AWS::S3::Errors::NoSuchKey => ex
    false
  end

  def s3_upload_object(local_file, bucket_name, key = nil)
    s3 = AWS::S3.new
    AWS.config.http_handler.pool.empty!

    key = File.basename(local_file) unless key
    CPW::logger.info "-->> start s3 upload: #{local_file}, #{bucket_name}, #{key}"
    s3.buckets[bucket_name].objects[key].write(File.open(local_file), content_length: File.size(local_file))
    CPW::logger.info "-->> finished s3 upload: #{local_file}, #{bucket_name}, #{key}"
  end

  def remove_all_s3_objects
    s3_delete_object_if_exists(APP_CONFIG['S3_INBOUND_BUCKET'], @ingest.upload.s3_key) if @ingest.upload
    s3_delete_object_if_exists(APP_CONFIG['S3_OUTBOUND_BUCKET'], @ingest.track.s3_key) if @ingest.track
    s3_delete_object_if_exists(APP_CONFIG['S3_OUTBOUND_BUCKET'], @ingest.track.s3_mp3_key) if @ingest.track
  end

  # -------------------------------------------------------------
  # ffmpeg
  # -------------------------------------------------------------

  def ffmpeg_audio_to_mp3(source_file, mp3_file, options = {})
    options = options.reverse_merge(bitrate: 128)
    # https://trac.ffmpeg.org/wiki/Encode/MP3
    # ffmpeg -i input.wav -codec:a libmp3lame -qscale:a 2 output.mp3
    # ffmpeg -i input.wav -codec:a libmp3lame -b:a 128k output.mp3
    # => ffmpeg -i input.avi -vn -ar 44100 -ac 2 -ab 192 -f mp3 output.mp3
    # cmd = "ffmpeg -y -i #{source_file} -f mp2 -b #{@bitrate}k #{mp3_file}   >/dev/null 2>&1"
    cmd = "ffmpeg -y -i #{source_file} -vn -ab #{options[:bitrate]}k -f mp3 #{mp3_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed converting audio to mp3 with bitrate #{options[:bitrate]}k: #{source_file}\n#{cmd}"
    end
  end

  def ffmpeg_audio_to_wav_and_single_channel(input_file, output_file)
    cmd = "ffmpeg -i #{input_file} -y -f wav -ac 1 #{output_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to wav and strip audio channel: #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_audio_to_wav(input_file, output_file, options = {})
    options = options.reverse_merge(audio_channels: 2)
    cmd = "ffmpeg -i #{input_file} -y -f wav -ac #{options[:audio_channels]} #{output_file}   >/dev/null 2>&1"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to wav (audio_channels: #{options[:audio_channels]}): #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_audio_to_pcm(input_file, output_file = nil, options = {})
    options = options.reverse_merge({sample_rate: 16000, endianness: system_endianness})
    cmd = "ffmpeg -i #{input_file} -y -ar #{options[:sample_rate]} -f s16#{options[:endianness]} -acodec pcm_s16#{options[:endianness]} #{output_file}"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to pcm and downsample: #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_audio_sampled(input_file, output_file = nil, options = {})
    options = options.reverse_merge({sample_rate: 16000})
    sampled_file = if !output_file || output_file == input_file
      input_file.gsub(/#{File.extname(input_file)}$/, ".transient-ar#{options[:sample_rate] / 1000}#{File.extname(input_file)}")
    else
      output_file
    end
    cmd = "ffmpeg -i #{input_file} -ar #{options[:sample_rate]} -y #{sampled_file}"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      if sampled_file != output_file
        File.delete(input_file)
        FileUtils.mv(sampled_file, input_file)
      end
      true
    else
      raise "Failed to sample with #{options[:sample_rate]}: #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_pcm_audio_to_wav(input_file, output_file, options = {})
    options = options.reverse_merge({sample_rate: 16000, channels: 1, endianness: system_endianness})
    cmd = "ffmpeg -f s16#{options[:endianness]} -ar #{options[:sample_rate]} -ac #{options[:channels]} -y -i #{input_file} #{output_file}"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to convert pcm audio to wav: #{input_file}\n#{cmd}"
    end
  end

  # :le => little endian
  # :be => big endian
  def system_endianness
    @system_endianness ||= begin
      out = `echo I | tr -d [:space:] | od -to2 | head -n1 | awk '{print $2}' | cut -c6`
      !!out.match(/1/) ? :le : :be
    end
  end

  # -------------------------------------------------------------
  # SOX
  # -------------------------------------------------------------

  def sox_normalize_audio(input_file, output_file)
    cmd = "sox #{input_file} #{output_file} \\" +
      "remix - \\" +
      "highpass 100 \\" +
      "norm \\" +
      "compand 0.05,0.2 6:-54,-90,-36,-36,-24,-24,0,-12 0 -90 0.1 \\" +
      "vad -T 0.6 -p 0.2 -t 5 \\" +
      "fade 0.1 \\" +
      "reverse \\" +
      "vad -T 0.6 -p 0.2 -t 5 \\" +
      "fade 0.1 \\" +
      "reverse \\" +
      "norm -0.5"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to normalize audio: #{input_file}\n#{cmd}"
    end
  end

  # -------------------------------------------------------------
  # QIO noise reduction
  # -------------------------------------------------------------

  def qio_silence_flags(input_file, output_file)
    vad_params = if @vad_silence_segments == 25 && @vad_noise_reduce
      "-S 1 -Length 25 \\" +
      "-VADweights #{ENV['AURORACALC']}/parameters/vad/net.tim-fin-tic-it-spn-rand.54i+50h+2o.0-delay-wiener+dct+lpf.wts.head \\" +
      "-VADnorm #{ENV['AURORACALC']}/parameters/vad/tim-fin-tic-it-spn-rand.0-delay-wiener+dct+lpf.norms \\"
    elsif @vad_silence_segments == 20 && !@vad_noise_reduce
      "-S 0 -Length 20 \\" +
      "-VADweights #{ENV['AURORACALC']}/parameters/vad/net.tim-fin-tic-spn-rand.54i+50h+2o.win20-mel-delay+dct+lpf.wts.head \\" +
      "-VADnorm #{ENV['AURORACALC']}/parameters/vad/tim-fin-tic-spn-rand.win20-mel-delay+dct+lpf.norms \\"
    else
      "-S 0 -Length 25 \\" +
      "-VADweights #{ENV['AURORACALC']}/parameters/vad/net.tim-fin-tic-spn-rand.54i+50h+2o.mel-delay+dct+lpf.wts.head \\" +
      "-VADnorm #{ENV['AURORACALC']}/parameters/vad/tim-fin-tic-spn-rand.mel-delay+dct+lpf.norms \\"
    end

    cmd = "silence_flags \\" +
      vad_params +
      "-fs 16000 \\" +
      "-swapin 0 \\" +
      "-i #{input_file} -o #{output_file} "

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to produce silence file: #{input_file}\n#{cmd}"
    end
  end

  def qio_noise_reduce(input_file, silence_file, output_file)
    length_and_shift = if @vad_silence_segments.modulo(2) == 0
      "-Length #{@vad_silence_segments} -Shift #{@vad_silence_segments / 2} \\"
    else
      "-Length #{@vad_silence_segments} \\"
    end

    cmd = "nr -fs 16000 -swapin 0 -swapout 0 \\" +
      length_and_shift +
      "-Ssilfile #{silence_file} \\" +
      "-i #{input_file} -o #{output_file}"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to noise reduce file: #{input_file}\n#{cmd}"
    end
  end

  # -------------------------------------------------------------
  # file management
  # -------------------------------------------------------------

  def delete_file_if_exists(file)
    CPW::logger.info "--> delete file #{file} if exists"
    File.delete(file) if file && File.exist?(file)
  end

  def copy_file(source_file, destination_file)
    CPW::logger.info "--> copy file #{source_file} to #{destination_file}"
    if source_file && File.exist?(source_file)
      FileUtils::mkdir_p "/#{File.join(destination_file.split("/").slice(1...-1))}"
      FileUtils.cp(source_file, destination_file)
    end
  end

  def move_file(source_file, destination_file)
    CPW::logger.info "--> move file #{source_file} to #{destination_file}"
    if source_file && File.exist?(source_file)
      FileUtils::mkdir_p "/#{File.join(destination_file.split("/").slice(1...-1))}"
      FileUtils.mv(source_file, destination_file)
    end
  end

  def copy_or_download(file_method_name)
    file_name = send(file_method_name)
    file_method_fullpath_name    = "#{file_method_name}_fullpath"
    current_stage_file_fullpath  = send(file_method_fullpath_name)

    # try to copy the file from one of the previous stages
    previous_stage_name = ingest.stage
    while previous_stage_name = ingest.previous_stage_name(previous_stage_name)
      previous_stage_file_fullpath = send(file_method_fullpath_name, ingest.uid, previous_stage_name)
      if File.exist?(previous_stage_file_fullpath)
        copy_file(previous_stage_file_fullpath, current_stage_file_fullpath)
        return
      end
    end

    # otherwise, download the file again
    logger.info "--> downloading from #{s3_origin_url_for(file_name)} to #{current_stage_file_fullpath}"
    s3_download_object ENV['S3_OUTBOUND_BUCKET'], s3_key_for(file_name), current_stage_file_fullpath
  end

  def copy_or_download_original_media_file
    previous_stage_original_media_file_fullpath = original_media_file_fullpath(@ingest.uid, self.class.previous_stage_name)

    if File.exist?(previous_stage_original_media_file_fullpath)
      copy_file(previous_stage_original_media_file_fullpath, original_media_file_fullpath)
    else
      logger.info "--> downloading from #{File.join(ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri)} to #{original_media_file_fullpath}"
      s3_download_object ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri, original_media_file_fullpath
    end
  end

  # -------------------------------------------------------------
  # waveform
  # -------------------------------------------------------------

  def waveform_sampling_rate(duration_in_secs, options = {})
    sampling_rate = 60
    max_samples   = 1000000
    result        = 1

    if options[:sampling_rate]
      result = options[:sampling_rate]
    else
      # determine sample rate
      while sampling_rate > 0
        total_samples = duration_in_secs.to_i * sampling_rate
        if total_samples < max_samples
          result = sampling_rate
          break
        end
        sampling_rate -= 1
      end
    end
    result
  end

  def wav2json(input_wav_file, output_json_file, options = {})
    options       = {channels: ['left', 'right'], precision: 2}.merge(options)
    channels      = [options[:channels]].flatten.map(&:split).flatten.join(' ')

    inspector     = CPW::Speech::AudioInspector.new(input_wav_file)
    duration      = inspector.duration.to_f
    sampling_rate = waveform_sampling_rate(duration_in_secs, options)
    total_samples = duration.to_i * sampling_rate

    cmd = "wav2json #{input_wav_file} --channels #{channels} --no-header --precision #{options[:precision]} --samples #{total_samples} -o #{output_json_file}"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to waveform audio: #{input_wav_file}\n#{cmd}"
    end
  end
end