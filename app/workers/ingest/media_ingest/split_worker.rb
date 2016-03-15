class Ingest::MediaIngest::SplitWorker < CPW::Worker::Base
  include CPW::Worker::Helper

  attr_accessor :engine

  self.finished_progress = 89

  SPHINX_MODELS = {
    "en" => {
      "dict" => "/cmudict-07a.dic",
      "lm" => "/lm_giga_64k_nvp_3gram.lm.dmp",
      # "lm" => "/ensemble_wiki_ng_se_so_subs_enron_congress_65k_pruned_huge_sorted_cased.lm.dmp",
      "hmm" => "/voxforge_en_sphinx.cd_cont_5000/",
    }
  }

  shoryuken_options queue: -> { queue_name },
    auto_delete: false, body_parser: :json

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    if ingest.use_source_annotations? && download_subtitle_file_if_exists
      process_with_srt
    else
      if ingest.metadata['te_name'] == "voicebase" || ingest.locale.match(/es/)
        process_with_voicebase
      elsif ingest.metadata['te_name'] == "kaldi"
        process_with_kaldi
      else
        process_with_pocketsphinx
      end
    end
  end

  protected

  def process_with_srt
    self.engine = CPW::Speech::Engines::SubtitleEngine.new(subtitle_file_fullpath,
      {format: :srt, default_chunk_score: 0.5})
    puts "****** process SRT: #{subtitle_file_fullpath}"
    engine.perform(basefolder: basefolder).each do |chunk|
      process_speech_chunk(chunk)
    end
  end

  def process_with_voicebase
    download_single_channel_wav_audio_file

    self.engine = CPW::Speech::Engines::VoiceBaseEngine.new(single_channel_wav_audio_file_fullpath,
      {external_id: ingest.uid, transcription_type: "machine-best"})
    puts "****** process VoiceBase: #{single_channel_wav_audio_file_fullpath}"
    engine.perform(locale: ingest.locale, basefolder: basefolder).each do |chunk|
      process_speech_chunk(chunk, {build_mp3: false, build_waveform: true})
    end

    cleanup_files
  end

  def process_with_kaldi
    raise "Need to implement kaldi"
  end

  def process_with_pocketsphinx
    download_single_channel_wav_audio_file
    create_raw_audio_from_wav

    # pocketsphinx_split
    configuration = ::Pocketsphinx::Configuration.default
    # According to: http://sourceforge.net/p/cmusphinx/discussion/help/thread/a85ee9a4/
    # -vad_prespeech  20
    # -vad_postspeech 45
    # -vad_threshold  2.0
    # configuration['vad_threshold'] = 4
    configuration['vad_prespeech']  = 20
    configuration['vad_postspeech'] = 45
    configuration['vad_threshold']  = 2
    configuration['dict']           = sphinx_model("dict") # path + "/cmu07a.dic"
    configuration['hmm']            = sphinx_model("hmm")  # path + "/voxforge_en_sphinx.cd_cont_5000/"
    configuration['lm']             = sphinx_model("lm")   # path + "/lm_giga_64k_nvp_3gram.lm.dmp"

    self.engine = CPW::Speech::Engines::PocketsphinxEngine.new(pcm_audio_file_fullpath,
      configuration, {source_file_type: :raw})

    puts "****** basefolder: #{basefolder}"
    puts "****** process pocketsphinx: #{single_channel_wav_audio_file_fullpath}"
    engine.perform(locale: ingest.locale, basefolder: basefolder).each do |chunk|
      process_speech_chunk(chunk, {build_mp3: true, build_waveform: true})
    end

    cleanup_files
  end

  def process_speech_chunk(chunk, options = {})
    if chunk.status > 0
      # build mp3 file
      if options[:build_mp3]
        chunk.build({source_file: single_channel_wav_audio_file_fullpath,
          base_file_type: :wav}).to_mp3

        puts "****** mp3_chunk: #{chunk.mp3_chunk}"
        puts "****** mp3_key: #{s3_key_for(File.basename(chunk.mp3_chunk))}"
        s3_upload_object(chunk.mp3_chunk, s3_origin_bucket_name, s3_key_for(File.basename(chunk.mp3_chunk)))
      end

      # build waveform file
      if options[:build_waveform]
        chunk.build({source_file: single_channel_wav_audio_file_fullpath,
          base_file_type: :wav}).to_waveform({channels: ['left', 'right']})

        puts "****** waveform_chunk: #{chunk.waveform_chunk}"
        puts "****** waveform_key: #{s3_key_for(File.basename(chunk.waveform_chunk))}"
        s3_upload_object(chunk.waveform_chunk, s3_origin_bucket_name, s3_key_for(File.basename(chunk.waveform_chunk)))
      end
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

    increment_progress!
  end

  def download_single_channel_wav_audio_file
    copy_or_download :single_channel_wav_audio_file
  end

  def create_raw_audio_from_wav
    ffmpeg_audio_to_pcm single_channel_wav_audio_file_fullpath, pcm_audio_file_fullpath
  end

  def cleanup_files
    if CPW::production?
      engine.clean if engine
      delete_file_if_exists pcm_audio_file_fullpath
      delete_file_if_exists single_channel_wav_audio_file_fullpath
      delete_file_if_exists subtitle_file_fullpath
    end
  end

  def create_or_update_ingest_with(chunk)
    ingest_chunk = nil
    CPW::Client::Base.try_request do
      ingest_chunk = Ingest::Chunk.where(ingest_id: @ingest.id,
        any_of_types: "pocketsphinx", any_of_positions: chunk.id,
        any_of_ingest_iterations: @ingest.iteration).first
    end

    start_at = Chronic.parse(@ingest.upload['recorded_at']) + chunk.offset.to_f rescue nil
    end_at   = start_at + chunk.duration.ceil if start_at

    track_attributes = {
      duration: chunk.duration,
      start_at: start_at,
      end_at: end_at
    }.tap do |h|
      h[:s3_url] = s3_origin_url_for(File.basename(chunk.mp3_chunk)) if chunk.mp3_chunk
      h[:s3_mp3_url] = s3_origin_url_for(File.basename(chunk.mp3_chunk)) if chunk.mp3_chunk
      h[:s3_waveform_json_url] = s3_origin_url_for(File.basename(chunk.waveform_chunk)) if chunk.waveform_chunk
      if ingest_chunk.try(:id) && ingest_chunk.track && ingest_chunk.track.try(:id)
        h[:id] = ingest_chunk.track.id
      end
    end

    chunk_attributes = {
      ingest_id: ingest.id,
      type: chunk_type_for(chunk),
      position: chunk.id,
      offset: chunk.offset,
      text: chunk.best_text,
      processing_errors: chunk.response['errors'],
      processing_status: chunk.status,
      response: chunk.response,
      track_attributes: track_attributes
    }.tap do |h|
      h[:score] = chunk.best_score if chunk.best_score
      h[:words] = chunk.words.to_json unless chunk.words.blank?
    end

    result = if ingest_chunk.try(:id)
      CPW::Client::Base.try_request do
        ingest_chunk.update_attributes(chunk_attributes)
      end
    else
      CPW::Client::Base.try_request do
        Ingest::Chunk.create(chunk_attributes)
      end
    end

    sleep 1 # be nice :-)

    result
  end

  private

  def chunk_type_for(chunk)
    case chunk.engine.class.name
    when /GoogleSpeechEngine/ then "Chunk::GoogleSpeechChunk"
    when /NuanceDragonEngine/ then "Chunk::NuanceDragonChunk"
    when /PocketsphinxEngine/ then "Chunk::PocketsphinxChunk"
    when /SubtitleEngine/ then "Chunk::SubtitleChunk"
    when /VoiceBaseEngine/ then "Chunk::VoiceBaseChunk"
    else
      raise ArgumentError, "unkown chunk type for #{chunk.inspect}"
    end
  end

  def sphinx_model(key)
    sources = sphinx_model_sources
    source  = sources[key]
    raise "Missing models for '#{key}' in '#{source}'" unless File.exists?(source)
    source
  end

  def sphinx_model_sources
    @sphinx_model_sources ||= begin
      locale = ingest.locale.downcase
      language, country = ingest.locale.split("-")

      sources, source_locale = if SPHINX_MODELS[locale]
        [SPHINX_MODELS[locale], locale]
      else SPHINX_MODELS[language]
        [SPHINX_MODELS[language], language]
      end
      raise "Missing models for locale '#{source_locale}' ('#{locale}')" unless sources

      sources = sources.inject({}) do |result, tuple|
        result[tuple.first] = File.join(CPW::models_root_path, "sphinx", source_locale, tuple.last)
        result
      end
      sources
    end
  end

  def download_subtitle_file_if_exists
    result = false
    if ingest.s3_origin_subtitle_key.present?
      copy_or_download :subtitle_file
      result = File.exist?(subtitle_file_fullpath)
    end
    result
  rescue AWS::S3::Errors::NoSuchKey => ex
    false
  end
end
