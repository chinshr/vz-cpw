require 'open-uri'
require 'youtube-dl.rb'

class Ingest::MediaIngest::HarvestWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  attr_accessor :media_file_fullpath_name, :srt_file_fullpath_name

  self.finished_progress = 19

  shoryuken_options queue: -> { queue_name },
    auto_delete: false, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    if ingest.has_s3_source_url?
      copy_media_from_s3_inbound_to_outbound_bucket
      # Delete inbound (uploaded) object
      s3_delete_object_if_exists(ENV['S3_INBOUND_BUCKET'], ingest.s3_upload_key)
    elsif ingest.has_ms_source_url?
      download_media_from_ms_source_url
      upload_ms_files_to_s3_outbound_bucket
    else
      download_media_from_raw_source_url
      upload_raw_file_to_s3_outbound_bucket
    end

    update_ingest_and_document_track
  end

  protected

  def download_media_from_ms_source_url(options = {})
    options = options.reverse_merge({
      output: File.join(basefolder, ingest.handle),
      merge_output_format: "mp4"
    })

    if ingest.use_source_annotations? && has_subtitle_locale_and_format?
      options.merge!({
        sub_format: "srt",
        sub_lang: select_subtitle_locale_from_supported_formats,
        write_sub: true,
        write_auto_sub: true
      })
      # -> "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.es-ES.srt"
      srt_locale = locale_subtitle_formats.first.try(:[], :locale)
      self.srt_file_fullpath_name = File.join(basefolder, "#{ingest.handle}.#{srt_locale}.srt")
    end

    ytdl = YoutubeDL.download(ingest.source_url, options)
    self.media_file_fullpath_name = ytdl.filename # -> E.g. "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.mp4"

    # determine file_type and update ingest
    inspector = CPW::Speech::AudioInspector.new(media_file_fullpath_name)
    update_ingest({
      file_type: inspector.file_type,
      file_size: inspector.file_size
    })

    ytdl
  end

  def upload_ms_files_to_s3_outbound_bucket
    # -> "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.mp4"
    s3_upload_object(media_file_fullpath_name, ingest.s3_origin_bucket_name, ingest.s3_origin_key)
    # -> "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.es-ES.srt"
    if srt_file_fullpath_name.present? && File.exist?(srt_file_fullpath_name)
      s3_upload_object(srt_file_fullpath_name,
        ingest.s3_origin_bucket_name, ingest.s3_origin_srt_key)
    end
  end

  def copy_media_from_s3_inbound_to_outbound_bucket
    # Copy the object from inbound to outbound folder.
    # E.g. //inbound/xyz123 -> //outbound/13dba008-7ba2-4804-a534-43d03c65260b/xyz123
    s3_copy_object_if_exists ENV['S3_INBOUND_BUCKET'], ingest.s3_upload_key,
      ingest.s3_origin_bucket_name, ingest.s3_origin_key
  end

  def download_media_from_raw_source_url
    self.media_file_fullpath_name = File.join(basefolder, ingest.handle)

    # create directory if not exists
    FileUtils::mkdir_p "/#{File.join(media_file_fullpath_name.split("/").slice(1...-1))}"

    File.open(media_file_fullpath_name, "wb") do |saved_file|
      open(ingest.source_url, "rb") do |read_file|
        saved_file.write(read_file.read)
      end
    end

    # determine file_type and update ingest
    inspector = CPW::Speech::AudioInspector.new(media_file_fullpath_name)
    update_ingest({
      file_type: inspector.file_type,
      file_size: inspector.file_size
    })
    media_file_fullpath_name
  end

  def upload_raw_file_to_s3_outbound_bucket
    s3_upload_object(media_file_fullpath_name,
      ingest.s3_origin_bucket_name, ingest.s3_origin_key)
  end

  def update_ingest_and_document_track
    document_tracks = Ingest::Track.where(ingest_id: ingest.id,
      any_of_types: "document")

    # Store the original file in the ingest
    ingest.update_attributes({
      origin_url: ingest.s3_origin_url
    })

    unless document_track = document_tracks.first
      # Create ingest's track and save s3 references
      # [POST] /api/ingests/:ingest_id/tracks.json?s3_url=abcd...
      Ingest::Track.create({
        type: "document_track",
        ingest_id: ingest.id,
        s3_url: ingest.s3_origin_url,
        ingest_iteration: ingest.iteration
      })
    else
      # Update ingest's document track with new iteration number
      # [PUT] /api/ingests/:ingest_id/tracks/:id.json?s3_url=abcd
      document_track.update_attributes({
        ingest_iteration: ingest.iteration
      })
    end
  end

  private

  def has_subtitle_locale_and_format?(format = "srt", exact_locale_match = false)
    formats = locale_subtitle_formats(format, exact_locale_match)
    formats.any? {|f| f[:formats].any? {|n| n.match(/#{format}/i) }}
  end

  def select_subtitle_locale_from_supported_formats(format = "srt", exact_locale_match = false)
    formats = locale_subtitle_formats(format, exact_locale_match)
    formats.each {|f| return f[:locale] if f[:formats].any? {|n| n.match(/#{format}/i) }}
  end

  def locale_subtitle_formats(format = "srt", exact_locale_match = false)
    locale = ingest.locale
    if exact_locale_match
      supported_subtitle_formats.select {|f| f[:locale].match(/#{locale}/)}
    else
      locale = locale.split(/[-_]/).first
      supported_subtitle_formats.map {|f| f[:language] = f[:locale].split(/[-_]/).first; f}.select {|f| f[:language].match(/#{locale}/)}
    end
  end

  def supported_subtitle_formats
    @supported_subtitle_formats ||= begin
      yt_video     = YoutubeDL.download(ingest.source_url, {list_subs: true})
      output       = yt_video.instance_variable_get("@last_download_output")
      header_index = output.index(/Available subtitles for (.*):/i)

      return nil if header_index.nil?

      formats = []
      output.slice(header_index..-1).split("\n").each do |line|
        format = {}
        format[:locale], format[:formats] = line.scan(/\A([a-z\-A-Z]+)\s+([a-zA-Z,\s]+)/)[0]
        formats.push format
      end
      formats = formats.slice(2..-1).reject {|f| f[:locale].blank?}

      return [] if formats.empty?

      formats.map do |format|
        format[:locale].strip!
        format[:formats] = format[:formats].split(",").map {|f| f.strip}
        format
      end
    end
  end
end
