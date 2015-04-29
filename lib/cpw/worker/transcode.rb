module CPW
  module Worker
    class Transcode < Worker::Base
      extend Worker::Helper

      MP3_BITRATE = 128

      def perform(message)
        download
        normalize
        noise_reduce
        create_mp3
        upload

        CPW::Worker::Transcribe.perform_async(message)
      ensure
        @ingest.update_attributes(progress: 25)
      end

      def download
        logger.info "--> downloading to #{original_audio_file_fullpath}"
        s3_download_object APP_CONFIG['S3_OUTBOUND_BUCKET'], @ingest.track.s3_key, original_audio_file_fullpath
      end

      def normalize
        # Create single WAV file
        logger.info "--> before ffmpeg_convert_to_wav_and_strip_audio_channel"
        ffmpeg_convert_to_wav_and_strip_audio_channel original_audio_file_fullpath, single_channel_audio_file_fullpath

        logger.info "--> before sox_normalize_audio"
        # Noise cancel and normalize it
        sox_normalize_audio single_channel_audio_file_fullpath, normalized_audio_file_fullpath

        # Delete the single channel file
        logger.info "--> delete single_channel_audio_file_fullpath"
        delete_file_if_exists single_channel_audio_file_fullpath
      end

      def noise_reduce
        FileUtils.copy(normalized_audio_file_fullpath, noise_reduced_wav_audio_file_fullpath)
      end

      def create_mp3
        # Convert to mp3
        ffmpeg_convert_to_mp3 noise_reduced_wav_audio_file_fullpath, mp3_audio_file_fullpath
      end

      def upload
        # Upload mp3
        s3_upload_object(mp3_audio_file_fullpath, @ingest.s3_origin_bucket_name, @ingest.s3_origin_mp3_key)

        # Update s3 references
        @ingest.track.update_attributes(s3_mp3_url: @ingest.s3_origin_mp3_url)

        # Remove mp3 file locally
        delete_file_if_exists mp3_audio_file_fullpath
      end

      protected

      def original_audio_file
        @ingest.track.s3_key if @ingest
      end

      def original_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, original_audio_file) if original_audio_file
      end

      def single_channel_audio_file
        "#{@ingest.track.s3_key}.single-channel" if @ingest
      end

      def single_channel_audio_file_fullpath
        File.join("/tmp", @ingest.uid, @ingest.stage, single_channel_audio_file) if single_channel_audio_file
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
    end
  end
end