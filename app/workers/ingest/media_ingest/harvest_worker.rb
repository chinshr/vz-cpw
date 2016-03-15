require 'open-uri'
require 'youtube-dl.rb'

class Ingest::MediaIngest::HarvestWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  YOUTUBE_DL_RETRIES = 10

  attr_accessor :media_file_fullpath_name
  attr_accessor :subtitle_file_fullpath_name

  self.finished_progress = 19

  shoryuken_options queue: -> { queue_name },
    auto_delete: false, body_parser: :json

  class TooManyRetries < StandardError; end

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
      # merge_output_format: "mp4"
      recode_video: "mp4",
      # rate_limit: "1M",
      retries: YOUTUBE_DL_RETRIES
    })

    if ingest.use_source_annotations? && has_subtitle_locale? # has_subtitle_locale_and_format?
      # youtube-dl https://www.youtube.com/watch?v=w2oLFpcMPlo --sub-format "srt/ttml/vtt" --write-auto-sub --convert-subs srt
      options.merge!({
        sub_format: "srt/ttml/vtt",
        convert_subs: "srt",
        sub_lang: select_subtitle_locale,
        write_sub: true,
        write_auto_sub: true
      })
      # -> "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.es-ES.srt"
      subtitle_locale = locale_subtitle_formats.first.try(:[], :locale)
      self.subtitle_file_fullpath_name = File.join(basefolder, "#{ingest.handle}.#{subtitle_locale}.srt")
    end

    ytdl, retries = nil, YOUTUBE_DL_RETRIES
    while true
      begin
        raise TooManyRetries, "YoutubeDL too many retries, source_url: #{ingest.source_url}, options: #{options}" unless retries > 0
        logger.info("+++ #{self.class.name}#perform, YoutubeDL (retries: #{retries}) source_url: #{ingest.source_url}, options: #{options}")
        ytdl = YoutubeDL.download(ingest.source_url, options)
      rescue Cocaine::ExitStatusError => ex
        logger.info("+++ #{self.class.name}#perform, YoutubeDL error: #{ex.message}")
        if ex.message.match(/ERROR: unable to download video data: HTTP Error 404: Not Found/i)
          retries -= 1
          retry # next
        else
          raise ex
        end
      rescue TooManyRetries => ex
        raise ex
      ensure
        retries = 0
        break
      end
    end
    raise "YoutubeDL did not like this source '#{ingest.source_url}'" if !ytdl || !ytdl.filename

    # -> E.g. "/tmp/5967f721-a799-4dec-a458-f7ff3a7fb377/harvest/2b6xguh240i5b3g13ktl.mp4"
    # Note: Bug in ytdl, will return a file with weird extension, need to normalize to mp4
    self.media_file_fullpath_name = ytdl.filename.gsub(File.extname(ytdl.filename), ".mp4")

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
    if subtitle_file_fullpath_name.present? && File.exist?(subtitle_file_fullpath_name)
      s3_upload_object(subtitle_file_fullpath_name, ingest.s3_origin_bucket_name, ingest.s3_origin_subtitle_key)
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
    CPW::Client::Base.try_request do
      document_tracks = Ingest::Track.where(ingest_id: ingest.id, any_of_types: "document")
    end

    # Store the original file in the ingest
    CPW::Client::Base.try_request do
      ingest.update_attributes({ origin_url: ingest.s3_origin_url })
    end

    unless document_track = document_tracks.first
      # Create ingest's track and save s3 references
      # [POST] /api/ingests/:ingest_id/tracks.json?s3_url=abcd...
      CPW::Client::Base.try_request do
        Ingest::Track.create({ type: "document_track", ingest_id: ingest.id, s3_url: ingest.s3_origin_url, ingest_iteration: ingest.iteration })
      end
    else
      # Update ingest's document track with new iteration number
      # [PUT] /api/ingests/:ingest_id/tracks/:id.json?s3_url=abcd
      CPW::Client::Base.try_request do
        document_track.update_attributes({
          ingest_iteration: ingest.iteration
        })
      end
    end
  end

  private

  def has_subtitle_locale_and_format?(format = "srt", exact_locale_match = false)
    formats = locale_subtitle_formats(format, exact_locale_match)
    formats.any? {|f| f[:formats].any? {|n| n.match(/#{format}/i) }}
  end

  def has_subtitle_locale?(exact_locale_match = false)
    locale_subtitle_formats.any? {|f| (f[:formats] || []).size > 0 }
  end

  def select_subtitle_locale_from_supported_formats(format = "srt", exact_locale_match = false)
    formats = locale_subtitle_formats(format, exact_locale_match)
    formats.each {|f| return f[:locale] if f[:formats].any? {|n| n.match(/#{format}/i) }}
  end

  def select_subtitle_locale(exact_locale_match = false)
    formats = locale_subtitle_formats
    formats.each {|f| return f[:locale] if f[:locale]}
  end

  def locale_subtitle_formats(format = "srt", exact_locale_match = false)
    locale = ingest.locale
    sl = if exact_locale_match
      supported_subtitle_formats.select {|f| f[:locale].match(/#{locale}/)}
    else
      locale = locale.split(/[-_]/).first
      supported_subtitle_formats.map {|f| f[:language] = f[:locale].split(/[-_]/).first; f}.select {|f| f[:language].match(/#{locale}/)}
    end
    sl
  end

  def supported_subtitle_formats
    @supported_subtitle_formats ||= begin
      yt_video     = YoutubeDL.download(ingest.source_url, {list_subs: true})
      output       = yt_video.instance_variable_get("@last_download_output")
      header_index = output.index(/(Available subtitles for|Available automatic captions for) (.*):/i)

      return @supported_subtitle_formats = [] if header_index.nil?

      formats = []
      output.slice(header_index..-1).split("\n").each do |line|
        format = {}
        format[:locale], format[:formats] = line.scan(/\A([a-z\-A-Z]+)\s+([a-zA-Z,\s]+)/)[0]
        formats.push format
      end
      formats = formats.slice(2..-1).reject {|f| f[:locale].blank?}

      return @supported_subtitle_formats = [] if formats.empty?

      formats.map do |format|
        format[:locale].strip!
        format[:formats] = format[:formats].split(",").map {|f| f.strip}
        format
      end
    end
  end
end
