class Ingest::MediaIngest::CrowdoutWorker < CPW::Worker::Base
  include CPW::Worker::Helper
  include CPW::Worker::ShoryukenHelper

  self.finished_progress = 95

  SOURCE_CHUNK_SCORE_THRESHOLD    = 0.8
  REFERENCE_CHUNK_SCORE_THRESHOLD = 0.95

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    # Chunks to be crowd sourced
    source_chunks = nil
    CPW::Client::Base.try_request({logger: logger}) do
      source_chunks = Ingest::Chunk.where({
        ingest_id: @ingest.id,
        any_of_ingest_iterations: @ingest.iteration,
        score_lt: SOURCE_CHUNK_SCORE_THRESHOLD,
        any_of_types: "pocketsphinx_chunk",
        any_of_processing_status: [::Speech::State::STATUS_PROCESSED],
        any_of_processed_stages: [:build, :convert]
      })
    end

    # Go through each source chunk, select those with low score
    # find a qualified high-confidence reference chunk and
    # merge the two into a CaptchaChunk.
    source_chunks.each do |source_chunk|
      logger.info "-> source_chunk = #{source_chunk.id}"

      reference_chunks = nil
      CPW::Client::Base.try_request({logger: logger}) do
        reference_chunks = Ingest::Chunk.where({
          none_of_ingest_ids: [@ingest.id],
          none_of_types: ["mechanical_turk_chunk", "captcha_chunk"],
          score_gteq: REFERENCE_CHUNK_SCORE_THRESHOLD,
          duration_lteq: source_chunk.duration.to_f + 3.0,
          any_of_locales: locale_language(source_chunk.locale),
          any_of_processing_status: [::Speech::State::STATUS_PROCESSED],
          any_of_processed_stages: [:build, :convert],
          sort_order: [:random], limit: 1
        })
      end

      logger.info "-> reference_chunks(#{reference_chunks.size}) = #{reference_chunks.map(&:id)}"
      if reference_chunks.size > 0
        merged_chunk = create_merged_chunk(source_chunk, reference_chunks)
      end
    end
  end

  protected

  def create_merged_chunk(source_chunk, reference_chunks)
    logger.info("Source chunk: #{source_chunk.inspect}")
    logger.info("Reference chunks: #{reference_chunks.to_a.inspect}")

    result         = 0
    chunks         = [source_chunk, reference_chunks].flatten.shuffle
    chunk_ids      = chunks.map(&:id)
    chunk_text     = chunks.map(&:text).join("|")
    chunk_duration = chunks.inject(0.0) {|r,c| r += c.duration}

    # * Download chunk tracks
    download_chunk_tracks(chunks)

    # * Merge audio files from tracks and convert to wav
    merged_wav_fullpath = merge_audio_tracks_and_convert_to_wav(chunks)

    # * Generate_waveform_json
    merged_waveform_json_fullpath = generate_waveform_json(merged_wav_fullpath)

    # * Convert merged WAV to mp3
    merged_mp3_fullpath = convert_wav_to_mp3(merged_wav_fullpath)

    # * Upload merged mp3 file
    merged_s3_mp3_url = upload_merged_mp3_file(merged_mp3_fullpath)

    # * Upload merged waveform json file
    merged_waveform_json_url = upload_merged_waveform_json_file(merged_waveform_json_fullpath)

    # * Calculate file duration
    audio    = CPW::Speech::AudioInspector.new(merged_wav_fullpath)
    start_at = Chronic.parse("now")
    end_at   = start_at + audio.duration.to_f.ceil if start_at

    # * Create chunk + track
    track_attributes = {
      s3_url: merged_s3_mp3_url,
      s3_mp3_url: merged_s3_mp3_url,
      s3_waveform_json_url: merged_waveform_json_url,
      duration: chunk_duration,
      start_at: start_at,
      end_at: end_at
    }

    chunk_attributes = {
      document_id: source_chunk.id,
      ingest_id: @ingest.id,
      type: "captcha_chunk",
      position: source_chunk.position,  # we don't need a position
      offset: 0,
      text: chunk_text,
      chunk_ids: chunk_ids,
      processing_status: 2, # TODO: used to be ENCODED
      track_attributes: track_attributes
    }

    CPW::Client::Base.try_request({logger: logger}) do
      result = Ingest::Chunk.create(chunk_attributes)
    end
    result
  ensure
    delete_file_if_exists(merged_wav_fullpath)
  end

  def download_chunk_tracks(*args)
    args.to_a.flatten.each do |chunk|
      copy_or_download_from_chunk_track(chunk, :s3_mp3_key)
    end
  end

  private

  def copy_or_download_from_chunk_track(chunk, key_attribute_name)
    file_name = File.basename(chunk.track.send(key_attribute_name))
    previous_stage_file_fullpath = expand_fullpath_name(file_name, @ingest.uid, @ingest.previous_stage_name)
    current_stage_file_fullpath  = expand_fullpath_name(file_name)

    if File.exist?(previous_stage_file_fullpath)
      logger.info "--> copying from #{previous_stage_file_fullpath} to #{current_stage_file_fullpath}"
      copy_file(previous_stage_file_fullpath, current_stage_file_fullpath)
    else
      logger.info "--> downloading from #{s3_origin_url_for(file_name)} to #{current_stage_file_fullpath}"
      s3_download_object ENV['S3_OUTBOUND_BUCKET'],
        chunk.track.send(key_attribute_name), current_stage_file_fullpath
    end
  end

  def merge_audio_tracks_and_convert_to_wav(chunks)
    tracks = chunks.flatten.map {|c| c.track}

    mp3_track_files_fullpath = tracks.map {|t| expand_fullpath_name(File.basename(t.s3_mp3_key))}
    wav_track_files_fullpath = mp3_track_files_fullpath.map {|f| replace_file_extension(f, ".wav") }

    output_wav_file = "merged-tracks-#{tracks.map(&:uid).join('+')}.wav"
    output_wav_file_fullpath = expand_fullpath_name(output_wav_file)

    # * Convert mp3 -> wav
    mp3_track_files_fullpath.each_with_index do |mp3_file, index|
      wav_file = wav_track_files_fullpath[index]
      ffmpeg_audio_to_wav(mp3_file, wav_file, {audio_channels: 1})
    end

    # * Merge wav files
    # input files E.g. "-i file1.wav -i file2.wav"
    input_files = wav_track_files_fullpath.map {|f| "-i #{f}"}.join(' ')
    # filter index E.g. "[0:0][1:0][2:0]"
    filter_index = tracks.size.times.inject("") {|r,i| r += "[#{i}:0]" }
    cmd = "ffmpeg -y #{input_files} \\" +
      "-filter_complex '#{filter_index}concat=n=#{tracks.size}:v=0:a=1[out]' \\" +
      "-map '[out]' #{output_wav_file_fullpath}"
    logger.info "-> $ #{cmd}"
    if system(cmd)
      output_wav_file_fullpath
    else
      raise "Failed merging wav tracks #{output_wav_file_fullpath}\n#{cmd}"
    end
  ensure
    wav_track_files_fullpath.each {|f| delete_file_if_exists(f)}
    mp3_track_files_fullpath.each {|f| delete_file_if_exists(f)}
  end

  def convert_wav_to_mp3(input_file)
    output_file = replace_file_extension(input_file, ".ab128k.mp3")
    ffmpeg_audio_to_mp3(input_file, output_file)
    output_file
  end

  def generate_waveform_json(input_file)
    output_file = replace_file_extension(input_file, ".waveform.json")
    wav2json(input_file, output_file)
    output_file
  end

  def upload_merged_mp3_file(merged_mp3_fullpath)
    file_name = File.basename(merged_mp3_fullpath)
    key = s3_key_for(file_name)
    url = s3_origin_url_for(file_name)
    s3_upload_object(merged_mp3_fullpath, s3_origin_bucket_name, key)
    url
  end

  def upload_merged_waveform_json_file(merged_waveform_json_fullpath)
    file_name = File.basename(merged_waveform_json_fullpath)
    key = s3_key_for(file_name)
    url = s3_origin_url_for(file_name)
    s3_upload_object(merged_waveform_json_fullpath, s3_origin_bucket_name, key)
    url
  end

  def locale_language(locale)
    locale.to_s.match(/^(\w{2})/) ? $1.to_s : nil
  end
end
