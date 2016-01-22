class Ingest::MediaIngest::TranscodeWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  self.finished_progress = 29

  MP3_BITRATE = 128
  STEPS = [:download, :normalize, :noise_reduce,
    :create_mp3, :create_waveform, :upload, :cleanup]

  shoryuken_options queue: -> { queue_name },
    auto_delete: false, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    STEPS.each do |step|
      send(step)
      increment_progress!
    end
  end

  def download
    copy_or_download :original_media_file
  end

  def normalize
    # Create single channel WAV file
    ffmpeg_audio_to_wav_and_single_channel original_media_file_fullpath, single_channel_wav_audio_file_fullpath

    # Create dual channel WAV file for MP3 and waveform processing
    ffmpeg_audio_to_wav original_media_file_fullpath, dual_channel_wav_audio_file_fullpath

    # Normalize single channel WAV
    sox_normalize_audio single_channel_wav_audio_file_fullpath, normalized_audio_file_fullpath
  end

  def noise_reduce
    FileUtils.copy(normalized_audio_file_fullpath, noise_reduced_wav_audio_file_fullpath)
  end

  def create_mp3
    ffmpeg_audio_to_mp3 dual_channel_wav_audio_file_fullpath,
      mp3_audio_file_fullpath, {bitrate: MP3_BITRATE}
  end

  def create_waveform
    wav2json dual_channel_wav_audio_file_fullpath, waveform_json_file_fullpath
  end

  def upload
    # Upload mp3
    s3_upload_object(mp3_audio_file_fullpath, s3_origin_bucket_name, @ingest.s3_origin_mp3_key)

    # Upload waveform json
    s3_upload_object(waveform_json_file_fullpath, s3_origin_bucket_name, @ingest.s3_origin_waveform_json_key)

    # Upload single channel WAV file
    s3_upload_object(single_channel_wav_audio_file_fullpath, s3_origin_bucket_name, single_channel_wav_audio_key)

    # Upload normalized + noise reduced audio
    # s3_upload_object(noise_reduced_wav_audio_file_fullpath, @ingest.s3_origin_bucket_name, noise_reduced_wav_audio_file)

    # Calculate file duration, start_at and end_at
    audio    = CPW::Speech::AudioInspector.new(dual_channel_wav_audio_file_fullpath)
    start_at = Chronic.parse(@ingest.upload['recorded_at'])
    end_at   = start_at + audio.duration.to_f.ceil if start_at

    # Update s3 references
    @ingest.track.update_attributes({
      s3_mp3_url: @ingest.s3_origin_mp3_url,
      s3_waveform_json_url: @ingest.s3_origin_waveform_json_url,
      duration: audio.duration.to_f,
      start_at: start_at,
      end_at: end_at
    })
  end

  def cleanup
    if CPW::production?
      # Delete original file
      delete_file_if_exists original_media_file_fullpath

      # Delete normalized
      delete_file_if_exists normalized_audio_file_fullpath

      # Delete noise reduced
      delete_file_if_exists noise_reduced_wav_audio_file_fullpath

      # Delete the single channel file
      # delete_file_if_exists single_channel_wav_audio_file_fullpath

      # Delete the dual channel file
      delete_file_if_exists dual_channel_wav_audio_file_fullpath

      # Remove mp3 file locally
      delete_file_if_exists mp3_audio_file_fullpath

      # Remove waveform json
      delete_file_if_exists waveform_json_file_fullpath
    end
  end

end
