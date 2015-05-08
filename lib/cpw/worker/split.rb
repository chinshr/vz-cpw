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
        configuration = ::Pocketsphinx::Configuration.default
        configuration['vad_threshold'] = 4

        engine = Speech::Engines::PocketsphinxEngine.new(pcm_audio_file_fullpath,
          configuration, {source_file_type: :raw})

        puts "****** basefolder: #{basefolder}"
        puts "****** file: #{single_channel_wav_audio_file_fullpath}"
        engine.perform(locale: "en-US", basefolder: basefolder).each do |chunk|
          if chunk.status > 0
            chunk.build({source_file: single_channel_wav_audio_file_fullpath,
              base_file_type: :wav}).to_mp3
            puts "****** mp3_chunk: #{chunk.mp3_chunk}"
            puts "****** mp3 s3_key: #{File.basename(chunk.mp3_chunk)}"

            s3_upload_object(chunk.mp3_chunk, s3_origin_bucket_name, File.basename(chunk.mp3_chunk))

          end
          # create_ingest_chunk(chunk)
          puts "****** chunk.id: #{chunk.id}"
          puts "****** chunk.status: #{chunk.status}"
          puts "****** chunk.best_text: #{chunk.best_text}"
          puts "****** chunk.best_score: #{chunk.best_score}"
          puts "****** chunk.offset: #{chunk.offset}"
          puts "****** chunk.duration: #{chunk.duration}"
          puts "****** chunk.response: #{chunk.response}"

          chunk.clean
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
        if CPW::production?
          delete_file_if_exists pcm_audio_file_fullpath
          delete_file_if_exists single_channel_wav_audio_file_fullpath
        end
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