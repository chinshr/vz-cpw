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
            chunk.build({source_file: single_channel_wav_audio_file_fullpath,
              base_file_type: :wav}).to_waveform({channels: []})

            puts "****** mp3_chunk: #{chunk.mp3_chunk}"
            puts "****** wafeform_chunk: #{chunk.waveform_chunk}"
            puts "****** mp3 s3_key: #{File.basename(chunk.mp3_chunk)}"

            s3_upload_object(chunk.mp3_chunk, s3_origin_bucket_name, File.basename(chunk.mp3_chunk))
            s3_upload_object(chunk.waveform_chunk, s3_origin_bucket_name, File.basename(chunk.waveform_chunk))
          end

          puts "****** chunk.id: #{chunk.id}"
          puts "****** chunk.status: #{chunk.status}"
          puts "****** chunk.best_text: #{chunk.best_text}"
          puts "****** chunk.best_score: #{chunk.best_score}"
          puts "****** chunk.offset: #{chunk.offset}"
          puts "****** chunk.duration: #{chunk.duration}"
          puts "****** chunk.response: #{chunk.response}"

          create_or_update_ingest_with chunk
          chunk.clean if CPW::production?
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

      def create_or_update_ingest_with(chunk)
        ingest_chunk = Ingest::Chunk.where(ingest_id: @ingest.id,
          any_of_type: "Chunk::Pocketsphinx", any_of_position: chunk.id,
          any_of_ingest_iteration: @ingest.iteration).first

        track_attributes = {s3_url: chunk.mp3_chunk, s3_mp3_url: chunk.mp3_chunk,
          s3_waveform_json_url: chunk.waveform_chunk}

        track_attributes.merge({id: ingest_chunk.track.id}) if ingest_chunk

        chunk_attributes = {
          ingest_id: @ingest.id,
          type: "Chunk::Pocketsphinx",
          position: chunk.id,
          offset: chunk.offset,
          duration: chunk.duration,
          start_time: chunk.offset,
          end_time: chunk.offset + chunk.duration,
          text: chunk.best_text,  # response[:hypothesis],
          score: chunk.best_score,  #response[:confidence],
          processing_errors: chunk.response['errors'],
          processing_status: chunk.status,
          response: chunk.response,
          track_attributes: track_attributes
        }

        if ingest_chunk.try(:id)
          ingest_chunk.update_attributes(chunk_attributes)
        else
          Ingest::Chunk.create(chunk_attributes)
        end
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