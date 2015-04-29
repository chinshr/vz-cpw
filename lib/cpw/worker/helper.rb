module CPW::Worker::Helper
  # -------------------------------------------------------------
  # S3
  # -------------------------------------------------------------

  def outbound_url(key)
    File.join(ENV['S3_URL'], ENV['S3_OUTBOUND_BUCKET'], key)
  end

  def s3_copy_object(source_bucket_name, destination_bucket_name, source_key, destination_key = nil)
    s3 = AWS::S3.new
    destination_key = source_key if destination_key.blank?
    s3.buckets[source_bucket_name].objects[source_key].copy_to(destination_key, :bucket_name => destination_bucket_name)
  end

  def s3_download_object(source_bucket_name, source_key, destination_filename)
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

  def ffmpeg_convert_to_mp3(source_file, mp3_file)
    # https://trac.ffmpeg.org/wiki/Encode/MP3
    # ffmpeg -i input.wav -codec:a libmp3lame -qscale:a 2 output.mp3
    # ffmpeg -i input.wav -codec:a libmp3lame -b:a 128k output.mp3
    # => ffmpeg -i input.avi -vn -ar 44100 -ac 2 -ab 192 -f mp3 output.mp3
    # cmd = "ffmpeg -y -i #{source_file} -f mp2 -b #{@mp3_bitrate}k #{mp3_file}   >/dev/null 2>&1"
    cmd = "ffmpeg -y -i #{source_file} -vn -ab #{@mp3_bitrate}k -f mp3 #{mp3_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed converting audio to mp3 with bitrate #{@mp3_bitrate}k: #{source_file}\n#{cmd}"
    end
  end

  def ffmpeg_convert_to_wav_and_strip_audio_channel(input_file, output_file)
    cmd = "ffmpeg -i #{input_file} -y -f wav -ac 1 #{output_file}   >/dev/null 2>&1"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to wav and strip audio channel: #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_downsample_and_convert_to_pcm(input_file, output_file)
    cmd = "ffmpeg -i #{input_file} -ar 16000 -y -f s16le -acodec pcm_s16le #{output_file}"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed convert audio to pcm and downsample: #{input_file}\n#{cmd}"
    end
  end

  def ffmpeg_convert_pcm_to_wav(input_file, output_file)
    cmd = "ffmpeg -f s16le -ar 16k -ac 1 -y -i #{input_file} #{output_file}"

    CPW::logger.info "-> $ #{cmd}"
    if system(cmd)
      true
    else
      raise "Failed to convert pcm file: #{input_file}\n#{cmd}"
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
    File.delete(file) if file && File.exist?(file)
  end

end