module CPW::Worker::Helper

  # -------------------------------------------------------------
  # file name helpers
  # -------------------------------------------------------------

  def basefolder(uid = nil, stage = nil)
    File.join("/tmp", (uid || @ingest.uid), (stage || @ingest.stage))
  end

  def expand_fullpath_name(file_name, uid = nil, stage = nil)
    File.join(basefolder(uid, stage), file_name)
  end

  # key is "<folder>/<file>"
  def original_audio_file
    @ingest.track.s3_key.split("/").last if @ingest && @ingest.track
  end

  def original_audio_key
    @ingest.track.s3_key if @ingest && @ingest.track
  end

  def original_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), original_audio_file) if original_audio_file
  end

  def single_channel_wav_audio_file
    "#{original_audio_file}.ac1.wav" if @ingest
  end

  def single_channel_wav_audio_key
    "#{original_audio_key}.ac1.wav" if @ingest
  end

  def single_channel_wav_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), single_channel_wav_audio_file) if single_channel_wav_audio_file
  end

  def dual_channel_wav_audio_file
    "#{original_audio_file}.ac2.wav" if @ingest
  end

  def dual_channel_wav_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), dual_channel_wav_audio_file) if dual_channel_wav_audio_file
  end

  def normalized_audio_file
    "#{original_audio_file}.ac1.normalized.wav" if @ingest
  end

  def normalized_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), normalized_audio_file) if normalized_audio_file
  end

  def noise_reduced_wav_audio_file
    "#{original_audio_file}.ac1.normalized.noise-reduced.wav" if @ingest
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
    "#{original_audio_file}.ac1.ar16k.#{endianness}.pcm" if @ingest
  end

  def pcm_audio_file_fullpath(uid = nil, stage = nil)
    File.join(basefolder(uid, stage), pcm_audio_file) if pcm_audio_file
  end

  # -------------------------------------------------------------
  # S3
  # -------------------------------------------------------------

  def s3_origin_bucket_name
    File.join(ENV['S3_OUTBOUND_BUCKET'])
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
    destination_key = source_key if destination_key.nil?
    if s3.buckets[source_bucket_name].objects[source_key].exists?
      s3.buckets[source_bucket_name].objects[source_key].copy_to(destination_key, :bucket_name => destination_bucket_name)
    end
  end

  def s3_delete_object(bucket_name, key)
    s3 = AWS::S3.new
    s3.buckets[bucket_name].objects.delete(key)
  end

  def s3_delete_object_if_exists(bucket_name, key)
    s3 = AWS::S3.new
    if bucket_name.present? && key.present? && s3.buckets[bucket_name].objects[key].exists?
      s3.buckets[bucket_name].objects.delete(key)
    end
    true
  rescue AWS::S3::Errors::NoSuchKey => ex
    false
  end

  def s3_upload_object(local_file, bucket_name, key = nil)
    s3 = AWS::S3.new
    AWS.config.http_handler.pool.empty!

    key = File.basename(local_file) unless key
    CPW::logger.info "-->> start s3 upload: #{local_file}, #{bucket_name}, #{key}"
    if false
      s3.buckets[bucket_name].objects[key].write(:file => local_file)
    else
      s3.buckets[bucket_name].objects[key].write(File.open(local_file), content_length: File.size(local_file))
    end
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
    options = options.reverse_merge(mp3_bitrate: 128)
    # https://trac.ffmpeg.org/wiki/Encode/MP3
    # ffmpeg -i input.wav -codec:a libmp3lame -qscale:a 2 output.mp3
    # ffmpeg -i input.wav -codec:a libmp3lame -b:a 128k output.mp3
    # => ffmpeg -i input.avi -vn -ar 44100 -ac 2 -ab 192 -f mp3 output.mp3
    # cmd = "ffmpeg -y -i #{source_file} -f mp2 -b #{@mp3_bitrate}k #{mp3_file}   >/dev/null 2>&1"
    cmd = "ffmpeg -y -i #{source_file} -vn -ab #{options[:mp3_bitrate]}k -f mp3 #{mp3_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed converting audio to mp3 with bitrate #{@mp3_bitrate}k: #{source_file}\n#{cmd}"
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

  def ffmpeg_audio_to_wav(input_file, output_file)
    cmd = "ffmpeg -i #{input_file} -y -f wav -ac 2 #{output_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to wav and strip audio channel: #{input_file}\n#{cmd}"
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
    file_method_fullpath_name = :"#{file_method_name}_fullpath"
    previous_stage_file_fullpath = send(file_method_fullpath_name, @ingest.uid, self.class.previous_stage_name)
    current_stage_file_fullpath  = send(file_method_fullpath_name)

    if File.exist?(previous_stage_file_fullpath)
      copy_file(previous_stage_file_fullpath, current_stage_file_fullpath)
    else
      logger.info "--> downloading from #{s3_origin_url_for(file_name)} to #{current_stage_file_fullpath}"
      s3_download_object ENV['S3_OUTBOUND_BUCKET'], s3_key_for(file_name), current_stage_file_fullpath
    end
  end

  def copy_or_download_original_audio_file
    previous_stage_original_audio_file_fullpath = original_audio_file_fullpath(@ingest.uid, self.class.previous_stage_name)

    if File.exist?(previous_stage_original_audio_file_fullpath)
      copy_file(previous_stage_original_audio_file_fullpath, original_audio_file_fullpath)
    else
      logger.info "--> downloading from #{File.join(ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri)} to #{original_audio_file_fullpath}"
      s3_download_object ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri, original_audio_file_fullpath
    end
  end

  # -------------------------------------------------------------
  # waveform
  # -------------------------------------------------------------

  def wav2json(input_wav_file, output_json_file)
    cmd = "wav2json #{input_wav_file} --channels left right -o #{output_json_file}"
    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to waveform audio: #{input_wav_file}\n#{cmd}"
    end
  end
end