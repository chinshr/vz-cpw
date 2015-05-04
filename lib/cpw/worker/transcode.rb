module CPW
  module Worker
    class Transcode < Worker::Base
      include Worker::Helper
      self.finished_progress = 25

      MP3_BITRATE = 128

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")
        download
        normalize
        noise_reduce
        create_mp3
        create_waveform
        upload
        cleanup
      end

      def download
        logger.info "--> downloading from #{File.join(ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri)} to #{original_audio_file_fullpath}"
        s3_download_object ENV['S3_OUTBOUND_BUCKET'], @ingest.track.s3_uri, original_audio_file_fullpath
      end

      def normalize
        # Create single channel WAV file
        ffmpeg_convert_to_wav_and_strip_audio_channel original_audio_file_fullpath, single_channel_wav_audio_file_fullpath

        # Create dual channel WAV file
        ffmpeg_convert_to_wav_and_keep_dual_audio_channel original_audio_file_fullpath, dual_channel_wav_audio_file_fullpath

        # Noise cancel and normalize it
        sox_normalize_audio single_channel_wav_audio_file_fullpath, normalized_audio_file_fullpath
      end

      def noise_reduce
        FileUtils.copy(normalized_audio_file_fullpath, noise_reduced_wav_audio_file_fullpath)
      end

      def create_mp3
        # Convert to mp3
        ffmpeg_convert_to_mp3 noise_reduced_wav_audio_file_fullpath,
          mp3_audio_file_fullpath, {mp3_bitrate: MP3_BITRATE}
      end

      def create_waveform
        wav2json dual_channel_wav_audio_file_fullpath, waveform_json_file_fullpath
      end

      def upload
        # Upload mp3
        s3_upload_object(mp3_audio_file_fullpath, @ingest.s3_origin_bucket_name, @ingest.s3_origin_mp3_key)

        # Upload waveform json
        s3_upload_object(waveform_json_file_fullpath, @ingest.s3_origin_bucket_name, @ingest.s3_origin_waveform_json_key)

        # Update s3 references
        @ingest.track.update_attributes(s3_mp3_url: @ingest.s3_origin_mp3_url,
          s3_waveform_json_url: @ingest.s3_origin_waveform_json_url)
      end

      def cleanup
        # Delete the single channel file
        # delete_file_if_exists single_channel_wav_audio_file_fullpath

        # Delete the dual channel file
        # delete_file_if_exists dual_channel_wav_audio_file_fullpath

        # Remove mp3 file locally
        # delete_file_if_exists mp3_audio_file_fullpath
      end

      protected

      def original_audio_file
        @ingest.track.s3_key if @ingest
      end

      def original_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, original_audio_file) if original_audio_file
      end

      def single_channel_wav_audio_file
        "#{@ingest.track.s3_key}.1ch.wav" if @ingest
      end

      def single_channel_wav_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, single_channel_wav_audio_file) if single_channel_wav_audio_file
      end

      def dual_channel_wav_audio_file
        "#{@ingest.track.s3_key}.2ch.wav" if @ingest
      end

      def dual_channel_wav_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, dual_channel_wav_audio_file) if dual_channel_wav_audio_file
      end

      def normalized_audio_file
        "#{@ingest.track.s3_key}.normalized.wav" if @ingest
      end

      def normalized_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, normalized_audio_file) if normalized_audio_file
      end

      def noise_reduced_wav_audio_file
        "#{@ingest.track.s3_key}.noise-reduced.wav" if @ingest
      end

      def noise_reduced_wav_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, noise_reduced_wav_audio_file) if noise_reduced_wav_audio_file
      end

      def mp3_audio_file
        @ingest.s3_origin_mp3_key
      end

      def mp3_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, mp3_audio_file) if mp3_audio_file
      end

      def waveform_json_file
        @ingest.s3_origin_waveform_json_key if @ingest
      end

      def waveform_json_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, waveform_json_file) if waveform_json_file
      end
    end
  end
end