module CPW
  module Worker
    class Crowdout < Worker::Base
      extend Worker::Helper

      SOURCE_CHUNK_SCORE_THRESHOLD    = 0.8
      REFERENCE_CHUNK_SCORE_THRESHOLD = 0.95

      shoryuken_options queue: -> { queue_name },
        auto_delete: true, body_parser: :json

      def perform(sqs_message, body)
        logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

        # Chunks to be crowd sourced
        source_chunks = Ingest::Chunk.where({ingest_id: @ingest.id,
          any_of_ingest_iterations: @ingest.iteration,
          score_lt: SOURCE_CHUNK_SCORE_THRESHOLD,
          any_of_types: "pocketsphinx"
        })

        # Go through each and find any high-confidence reference chunk
        source_chunks.each do |source_chunk|
          reference_chunks = Ingest::Chunk.where({
            none_of_ingest_ids: [@ingest.id],
            none_of_types: ["mechanical_turk"],
            score_gteq: REFERENCE_CHUNK_SCORE_THRESHOLD,
            duration_lteq: source_chunk.duration.to_f + 3.0,
            any_of_locales: locale_language(source_chunk.locale),
            sort_order: [:random], limit: 1
          })

          merged_chunk = create_merged_chunk(source_chunk, reference_chunks)
        end
      end

      protected

      def create_merged_chunk(source_chunk, reference_chunks)
        logger.info("Source chunk: #{source_chunk.inspect}")
        logger.info("Reference chunks: #{reference_chunks.to_a.inspect}")

        chunks         = [source_chunk, reference_chunks].flatten.shuffle
        chunk_ids      = chunks.map(&:id)
        chunk_text     = chunks.map(&:text).join("|")
        chunk_duration = chunks.inject(0.0) {|r,c| r += c.duration}

        # * Download chunk tracks
        download_chunk_tracks(chunks)

        # * Merge mp3 files
        merged_mp3_fullpath = merge_mp3_tracks(chunks)

        # * Generate_waveform_json
        merged_waveform_json_fullpath = generate_waveform_json(merged_mp3_fullpath)

        # * Upload merged mp3 file
        merged_s3_mp3_url = upload_merged_mp3_file(merged_mp3_fullpath)

        # * Upload merged waveform json file
        merged_waveform_json_url = upload_merged_waveform_json_file(merged_waveform_json_fullpath)

        # * Create chunk + track
        track_attributes = {
          s3_url: merged_s3_mp3_url,
          s3_mp3_url: merged_s3_mp3_url,
          s3_waveform_json_url: merged_waveform_json_url
        }

        chunk_attributes = {
          ingest_id: @ingest.id,
          type: "captcha",
          position: -1,  # we don't need a position
          offset: 0,
          duration: chunk_duration,
          text: chunk_text,
          chunk_ids: chunk_ids,
          processing_status: Chunk::STATUS_ENCODED,
          track_attributes: track_attributes
        }

        Ingest::Chunk.create(chunk_attributes)
      end

      def download_chunk_tracks(*args)
        args.to_a.flatten.each do |chunk|
          copy_or_download_from_chunk_track(chunk, :s3_mp3_key)
        end
      end

      private

      def copy_or_download_from_chunk_track(chunk, key_attribute_name)
        file_name = File.basename(chunk.track.send(key_attribute_name))
        previous_stage_file_fullpath = expand_fullpath_name(file_name, @ingest.uid, self.class.previous_stage_name)
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

      def merge_mp3_tracks(chunks)
        tracks = chunks.flatten.map {|c| c.tracks}
        tracks_files_fullpath = track.map {|t| expand_fullpath_name(File.basename(track.s3_mp3_key))}
        output_file = "merged-tracks-#{tracks.map(&:uid).join('+')}.128k.mp3"
        output_file_fullpath = expand_fullpath_name(output_file)

        cmd = %(ffmpeg -i "concat:#{tracks_files_fullpath.join('|')}" -c copy #{output_file_fullpath})
        logger.info "-> $ #{cmd}"
        if system(cmd)
          output_file_fullpath
        else
          raise "Failed merging mp3 tracks #{tracks_files_fullpath.join('|')}\n#{cmd}"
        end
      end

      def generate_waveform_json(input_file)
        output_file = input_file.gsub(/#{File.extname(input_file)}$/, ".waveform.json")
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
        s3_upload_object(merged_mp3_fullpath, s3_origin_bucket_name, key)
        url
      end

      def locale_language(locale)
        locale.to_s.match(/^(\w{2})/) ? $1.to_s : nil
      end
    end
  end
end