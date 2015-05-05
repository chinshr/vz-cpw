require 'pocketsphinx-ruby'

module CPW
  module Worker
    class Chunk < Worker::Base
      include Worker::Helper

      self.finished_progress = 80

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        download
        convert

        recognizer = Pocketsphinx::AudioFileSpeechRecognizer.new
        recognizer.recognize(pcm_audio_file_fullpath) do |speech|
          logger.info speech
        end

        cleanup
      end

      protected

      def download
        copy_or_download_original_audio_file
      end

      def convert
        ffmpeg_downsample_and_convert_to_pcm(original_audio_file_fullpath, pcm_audio_file_fullpath)
      end

      def cleanup
      end

      def update_ingest
        Ingest::Chunk.create(ingest_id: @ingest.id, text: "test", offset: 0,
          track_attributes: {s3_url: "track-1.url", s3_mp3_url: "track-1.128.mp3.url"})
      end

    end
  end
end