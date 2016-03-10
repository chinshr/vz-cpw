class Ingest < CPW::Client::Base
  uri "ingests/(:id)"
  include_root_in_json :ingest

  STATE_CREATED     = 0
  STATE_STARTING    = 1
  STATE_STARTED     = 2
  STATE_STOPPING    = 3
  STATE_STOPPED     = 4
  STATE_RESETTING   = 5
  STATE_RESET       = 6
  STATE_REMOVING    = 7
  STATE_REMOVED     = 8
  STATE_FINISHED    = 9
  STATE_RESTARTING  = 10
  STATES = {
    created: STATE_CREATED, starting: STATE_STARTING, started: STATE_STARTED,
    stopping: STATE_STOPPING, stopped: STATE_STOPPED, resetting: STATE_RESETTING,
    reset: STATE_RESET, removing: STATE_REMOVING, removed: STATE_REMOVED,
    finished: STATE_FINISHED,  restarting: STATE_RESTARTING
  }
  EVENTS = [:start, :stop, :reset, :remove, :process, :finish, :fail, :restart]

  belongs_to :document
  has_many :chunks, uri: "ingests/:ingest_id/chunks/(:id)", class_name: "Ingest::Chunk"
  has_many :tracks, uri: "ingests/:ingest_id/tracks/(:id)?none_of_types[]=document_track", class_name: "Ingest::Track"
  has_many :tracks_including_master_track, uri: "ingests/:ingest_id/tracks/(:id)", class_name: "Ingest::Track"

  scope :started, -> { where(any_of_status: Ingest::STATE_STARTED) }

  class << self
    @@semaphore = Mutex.new

    def secure_find(id)
      @@semaphore.synchronize do
        Ingest.find(id)
      end
    end

    def secure_update(id, attributes)
      @@semaphore.synchronize do
        if (ingest = Ingest.find(id)) && ingest.try(:id)
          ingest.update_attributes(attributes)
        end
        ingest
      end
    end
  end  # class methods

  def present?
    !!self.try(:id)
  end

  def stage
    self[:stage].try(&:to_sym)
  end

  def stages
    (self[:stages] || []).map(&:to_sym)
  end

  def stage_names
    (self[:stages] || []).map {|n| stage_trunk_name(n) }
  end

  def previous_stage(from_stage = stage)
    stages[stages.index(from_stage.to_sym) - 1] if !from_stage.blank? && stages.index(from_stage.to_sym) - 1 >= 0
  end

  def previous_stage_name(from_stage_or_stage_name = stage)
    from_stage = from_stage_or_stage_name.to_s.match(/_stage$/i) ? from_stage_or_stage_name : "#{from_stage_or_stage_name}_stage"
    stage_trunk_name(previous_stage(from_stage)) unless from_stage_or_stage_name.blank?
  end

  def next_stage
    stages[stages.index(stage) + 1]
  end

  def next_stage_name
    stage_trunk_name(next_stage)
  end

  # state helpers
  STATES.each do |state, value|
    # State inquiry, e.g. @ingest.stopped?
    define_method("#{state}?") do
      STATES[state] == self.status
    end
  end

  EVENTS.each do |event|
    # Set event, e.g. @ingest.stop
    define_method("#{event}") do
      self.send(:"event=", event)
    end

    # Force event, e.g. @ingest.stop!
    define_method("#{event}!") do
      update_attributes({event: event})
      !errors[:status]
      self
    end
  end

  # Adds stage helper methods
  # E.g. harvest_stage?
  def method_missing(method_name, *arguments)
    if inquiry = method_name[/^(\w+)_stage\?/, 1].try(:to_s)
      self.stage_name == inquiry
    else
      super
    end
  end

  def track
    @track ||= begin
      tracks_including_master_track.where(any_of_types: ["document_track"]).first
    end
  end

  def state
    STATES.keys[status].try(:to_sym)
  end

  def s3_upload_key
    handle
  end

  def s3_origin_bucket_name
    ENV['S3_OUTBOUND_BUCKET']
  end

  def s3_origin_key
    if origin_url
      path = URI.parse(origin_url).path.split("/").reject(&:blank?)
      File.join(path.slice(1..-1)) if path && path.length > 0
    else
      # to be used for main track
      File.join(uid, File.basename(handle))
    end
  rescue URI::InvalidURIError => ex
    nil
  end

  def s3_origin_url
    if origin_url
      self[:origin_url]
    else
      File.join(ENV['S3_URL'], ENV['S3_OUTBOUND_BUCKET'], self.s3_origin_key)
    end
  end

  def s3_origin_mp3_key
    if self.track && self.track.try(:s3_mp3_key)
      # already uploaded as url
      self.track.s3_mp3_key
    elsif self.track && self.track.try(:s3_key)
      # when created
      "#{self.track.s3_key}.ac2.ab#{Ingest::MediaIngest::TranscodeWorker::MP3_BITRATE}K.mp3"
    else
      raise "Could not derive 's3_origin_mp3_key'"
    end
  end

  def s3_origin_mp3_url
    if self.track && self.track.try(:s3_mp3_url)
      self.track.s3_mp3_url
    else
      File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_mp3_key)
    end
  end

  def s3_origin_waveform_json_key
    if self.track && self.track.s3_waveform_json_key
      # already uploaded as url
      self.track.s3_waveform_json_key
    elsif self.track && self.track.s3_key
      # when being created
      "#{self.track.s3_key}.ac2.waveform.json"
    else
      raise "Could not derive 's3_origin_waveform_json_key'"
    end
  end

  def s3_origin_waveform_json_url
    if self.track && self.track.s3_waveform_json_url
      self.track.s3_waveform_json_url
    else
      File.join(ENV['S3_URL'], s3_origin_bucket_name, s3_origin_waveform_json_key)
    end
  end

  def s3_origin_subtitle_key
    if self.track && self.track.s3_key
      # when being created
      "#{self.track.s3_key}.#{self.locale}.srt"
    elsif self.s3_origin_key
      "#{self.s3_origin_key}.#{self.locale}.srt"
    else
      raise "Could not derive 's3_origin_subtitle_key'"
    end
  end

  def set_progress!(percent)
    new_progress = percent
    new_progress = new_progress > 100 ? 100 : new_progress
    update_attribute(:progress, new_progress)
  end

  # E.g. "harvest_stage" -> "harvest"
  def stage_name
    stage_trunk_name(self[:stage])
  end

  def has_s3_source_url?
    result = false
    if has_source_url?
      uri = URI.parse(source_url)
      result = !!(uri.host.try(:match, /^s3.amazonaws.com$/i) &&
        uri.path.try(:match, /#{ENV['S3_INBOUND_BUCKET']}/i))
    end
    result
  end

  def has_ms_source_url?
    result = false
    if has_source_url?
      result = !!(metadata['target'] && metadata['target']['ms_name'])
    end
    result
  end

  def has_source_url?
    source_url.present?
  end

  def use_source_annotations?
    !!self.use_source_annotations
  end

  private

  # E.g. :archive_stage -> 'archive'
  def stage_trunk_name(name)
    "#{name}".gsub(/_stage/i, '') if name
  end

end
