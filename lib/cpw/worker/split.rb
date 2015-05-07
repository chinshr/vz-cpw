module CPW
  module Worker
    class Split < Worker::Base
      attr_accessor :splitter

      include Worker::Helper
      self.finished_progress = 80

      shoryuken_options queue: -> { queue_name },
        auto_delete: false, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        download
        create_raw
        split
        cleanup
      end

      protected

      def split
        # file = "/Users/juergen/work/vzo/vz-cpw/examples/assets/audio/i-like-pickles.raw"
        # file = "/Users/juergen/work/vzo/vz-cpw/examples/assets/audio/i-like-pickles.pcm"
        # file = "/tmp/d155ef63-0e83-4661-b672-955fd7578a73/transcode/guj58l1j7l.noise-reduced.wav"
        # file = "/tmp/d155ef63-0e83-4661-b672-955fd7578a73/transcode/guj58l1j7l.noise-reduced.pcm"
        file = pcm_audio_file_fullpath
        configuration = ::Pocketsphinx::Configuration.default
        configuration['vad_threshold'] = 4

        engine = Speech::Engines::PocketsphinxEngine.new(file, configuration)
        puts "****** basefolder: #{basefolder}"
        puts "****** file: #{file}"
        engine.perform(locale: "en-US", basefolder: basefolder).each do |chunk|
          puts "****** mp3_chunk: #{chunk.mp3_chunk}"
          if false && chunk.mp3_chunk
            s3_upload_object(chunk.mp3_chunk, @ingest.s3_origin_bucket_name)
          end
          # create_ingest_chunk(chunk)
          puts "****** chunk.best_text: #{chunk.best_text}"
          puts "****** chunk.response: #{chunk.response}"
        end

        if false
          recognizer = CPW::Pocketsphinx::AudioFileSpeechRecognizer.new(configuration)
          recognizer.recognize(file) do |decoder|


            if decoder.respond_to?(:hypothesis) && decoder.hypothesis
              logger.info "++++++ #{decoder.hypothesis}"
              logger.info "++++++ #{decoder.hypothesis.path_score}"
              logger.info "++++++ #{decoder.words.to_json}"

            end
          end
        elsif false
          decoder = ::Pocketsphinx::Decoder.new(configuration)
          decoder.decode file

          logger.info "++++++ #{decoder.class}"
          logger.info "++++++ #{decoder.hypothesis}"
          logger.info "++++++ #{decoder.hypothesis.path_score}"
          logger.info "++++++ #{decoder.words.to_json}"
        end
      end

      def download
        copy_or_download :single_channel_wav_audio_file
      end

      def create_raw
        # ffmpeg_audio_sampled(single_channel_wav_audio_file_fullpath, pcm_audio_file_fullpath)
        ffmpeg_audio_to_pcm(single_channel_wav_audio_file_fullpath, pcm_audio_file_fullpath)
      end

      def cleanup
        # delete_file_if_exists pcm_audio_file_fullpath
      end

      def create_ingest_chunk(chunk)
        s3_url = File.join(@ingest.s3_origin_bucket_name, chunk.mp3_chunk)
        Ingest::Chunk.create({
          ingest_id: @ingest.id,
          type: "Chunk::Pocketsphinx",
          position: chunk.id,
          offset: chunk.offset,
          duration: chunk.duration,
          start_time: chunk.offset,
          end_time: chunk.offset + chunk.duration,
          text: chunk.best_text,  # response[:hypothesis],
          score: chunk.score,  #response[:confidence],
          processing_errors: chunk.response['errors'],
          processing_status: chunk.status,
          response: chunk.response,
          track_attributes: {s3_url: s3_url, s3_mp3_url: s3_url}
        })
      end

      class AudioChunk
        attr_reader :decoder, :offset, :duration, :id

        def initialize(decoder, offset, duration, id = nil)
          self.decoder  = decoder
          self.offset   = offset
          self.duration = duration
          self.id       = id

          start_time = decode_start_time(decoder)
            offset     = decode_start_time(decoder)
            duration   = decode_duration(decoder)
            end_time   = start_time + BigDecimal.new(duration.to_s)


        end
      end
    end
  end
end