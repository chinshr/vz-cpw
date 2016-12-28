class Ingest::MediaIngest::SplitWorker < CPW::Worker::Base
  include CPW::Worker::Helper
  include CPW::Worker::ShoryukenHelper

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

  def perform(sqs_message, body)
    logger.info("+++ #{self.class.name}#perform, body #{body.inspect}")

    if ingest.use_source_annotations? && download_subtitle_file_if_exists
      process_with_subtitle_engine
    else
      case ingest.metadata['te_name'].to_s
      when /voicebase/, /rambutan/ then process_with_voicebase_engine
      when /pocketsphinx/, /lychee/ then process_with_pocketsphinx_engine
      when /google_cloud_speech/, /physalis/ then process_with_google_cloud_speech_engine
      when /ibm_watson_speech/, /pomgranate/ then process_with_ibm_watson_speech_engine
      when /speechmatics/, /raspberry/ then process_with_speechmatics_engine
      else
        # default
        process_with_google_cloud_speech_engine
      end
    end
    cleanup_files
  end

  protected

  def process_with_subtitle_engine
    self.engine = CPW::Speech::Engines::SubtitleEngine.new(
      subtitle_file_fullpath,
      {format: :srt, default_chunk_score: 0.8})
    engine_perform
  end

  def process_with_voicebase_engine
    download_single_channel_wav_audio_file

    self.engine = CPW::Speech::Engines::VoicebaseEngine.new(
      single_channel_wav_audio_file_fullpath,
      default_engine_options({
        api_version: "2.0",
        external_id: ingest.uid,
        transcription_type: "machine-best",
        split_method: :auto
      }))
    engine_perform
  end

  def process_with_pocketsphinx_engine
    download_single_channel_wav_audio_file

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

    self.engine = CPW::Speech::Engines::PocketsphinxEngine.new(
      single_channel_wav_audio_file_fullpath,
      default_engine_options({
        configuration: configuration,
        source_file_type: :wav
      }))
    engine_perform
  end

  def process_with_google_cloud_speech_engine
    download_single_channel_wav_audio_file
    self.engine = CPW::Speech::Engines::GoogleCloudSpeechEngine.new(
      single_channel_wav_audio_file_fullpath,
      default_engine_options({
        source_file_type: :wav
      }))
    engine_perform
  end

  def process_with_ibm_watson_speech_engine
    download_single_channel_wav_audio_file

    self.engine = CPW::Speech::Engines::IbmWatsonSpeechEngine.new(
      single_channel_wav_audio_file_fullpath,
      default_engine_options({
        source_file_type: :wav
      }))
    engine_perform
  end

  def process_with_speechmatics_engine
    download_single_channel_wav_audio_file

    self.engine = CPW::Speech::Engines::SpeechmaticsEngine.new(
      single_channel_wav_audio_file_fullpath,
      default_engine_options({
        source_file_type: :wav
      }))
    engine_perform
  end

  def engine_perform(perform_options = {}, speech_chunk_options = {})
    # perform options
    perform_options = {
      locale: ingest.locale,
      basefolder: basefolder
    }.merge(perform_options)

    # speech_chunk_options
    speech_chunk_options = {
      build_mp3: false,
      build_waveform: false,
      build_speaker_gmm: true
    }.merge(speech_chunk_options)

    # logs
    logger.info "****** processing with `#{engine.class.name}`"
    logger.info "****** basefolder: #{basefolder}"
    logger.info "****** ingest locale: #{ingest.locale}"

    # load previously converted chunks
    # preload_converted_ingest_chunks(engine, perform_options)

    # perform
    engine.perform(perform_options).each do |speech_chunk|
      process_speech_chunk(speech_chunk, speech_chunk_options)
    end
  end

  def preload_converted_ingest_chunks(engine = self.engine, options = {})
    ingest_chunks, repeat = [], true
    offset, limit = 0, 25

    while repeat do
      ingest_chunks_page = CPW::Client::Base.try_request({logger: logger}) do
        Ingest::Chunk.where({
          ingest_id: @ingest.id,
          any_of_types: ingest_chunk_type_for(engine),
          any_of_locales: @ingest.locale,
          any_of_ingest_iterations: @ingest.iteration,
          any_of_processing_status: ::Speech::State::STATUS_PROCESSED,
          any_of_processed_stages: [:convert],
          sort_order: {position: :asc},
          offset: offset
        }).to_a
      end
      if ingest_chunks_page.size == 0
        repeat = false
      else
        ingest_chunks += ingest_chunks_page
        if limit == ingest_chunks_page.size
          offset += limit
        else
          repeat = false
        end
      end
    end
    # now, import chunks to engine
    engine.import(ingest_chunks, {processed_stages: :split}.merge(options))
    engine
  end

  def process_speech_chunk(speech_chunk, options = {})
    if speech_chunk.status == ::Speech::State::STATUS_PROCESSED
      # build chunk's mp3 file
      if options[:build_mp3]
        speech_chunk.build({
          source_file: single_channel_wav_audio_file_fullpath,
          base_file_type: :wav
        }).to_mp3

        logger.info "****** mp3_file_name: #{speech_chunk.mp3_file_name}"
        logger.info "****** mp3_key: #{s3_key_for(File.basename(speech_chunk.mp3_file_name))}"
        s3_upload_object(speech_chunk.mp3_file_name, s3_origin_bucket_name, s3_key_for(File.basename(speech_chunk.mp3_file_name)))
      end

      # build chunk's waveform file
      if options[:build_waveform]
        speech_chunk.build({
          source_file: single_channel_wav_audio_file_fullpath,
          base_file_type: :wav
        }).to_waveform({channels: ['left', 'right']})

        logger.info "****** waveform_file_name: #{speech_chunk.waveform_file_name}"
        logger.info "****** waveform_key: #{s3_key_for(File.basename(speech_chunk.waveform_file_name))}"
        s3_upload_object(speech_chunk.waveform_file_name, s3_origin_bucket_name, s3_key_for(File.basename(speech_chunk.waveform_file_name)))
      end

      if options[:build_speaker_gmm] && !!speech_chunk.speaker_gmm_file_name && File.exist?(speech_chunk.speaker_gmm_file_name)
        logger.info "****** speaker_gmm_chunk: #{speech_chunk.speaker_gmm_file_name}"
        logger.info "****** speaker_gmm_key: #{s3_key_for(File.basename(speech_chunk.speaker_gmm_file_name))}"
        s3_upload_object(speech_chunk.speaker_gmm_file_name, s3_origin_bucket_name, s3_key_for(File.basename(speech_chunk.speaker_gmm_file_name)))
        add_speech_chunk_speaker_to_lsh_index(speech_chunk)
      end
    end

    logger.info "****** chunk.position: #{speech_chunk.position}"
    logger.info "****** chunk.id: #{speech_chunk.id}"
    logger.info "****** chunk.status: #{speech_chunk.status}"
    logger.info "****** chunk.best_text: #{speech_chunk.best_text}"
    logger.info "****** chunk.best_score: #{speech_chunk.best_score}"
    logger.info "****** chunk.offset: #{speech_chunk.offset}"
    logger.info "****** chunk.duration: #{speech_chunk.duration}"
    logger.info "****** chunk.as_json: #{speech_chunk.as_json.inspect}"

    # save
    create_or_update_ingest_chunk_with(speech_chunk)

    # cleanup
    speech_chunk.clean
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

  def create_or_update_ingest_chunk_with(speech_chunk)
    ingest_chunk = nil
    CPW::Client::Base.try_request({logger: logger}) do
      ingest_chunk = Ingest::Chunk.where({
        ingest_id: @ingest.id,
        any_of_types: ingest_chunk_type_for(speech_chunk),
        any_of_positions: speech_chunk.id,
        any_of_ingest_iterations: @ingest.iteration
      }).first
    end

    start_at = Chronic.parse(@ingest.upload['recorded_at']) + speech_chunk.offset.to_f rescue nil
    end_at   = start_at + speech_chunk.duration.ceil if start_at

    track_attributes = {
      duration: speech_chunk.duration,
      start_at: start_at,
      end_at: end_at
    }.tap do |h|
      h[:s3_url] = s3_origin_url_for(File.basename(speech_chunk.mp3_file_name)) if speech_chunk.mp3_file_name
      h[:s3_mp3_url] = s3_origin_url_for(File.basename(speech_chunk.mp3_file_name)) if speech_chunk.mp3_file_name
      h[:s3_waveform_json_url] = s3_origin_url_for(File.basename(speech_chunk.waveform_file_name)) if speech_chunk.waveform_file_name
      if ingest_chunk.try(:id) && ingest_chunk.track && ingest_chunk.track.try(:id)
        h[:id] = ingest_chunk.track.id
      end
    end

    chunk_attributes = {
      ingest_id: ingest.id,
      type: ingest_chunk_type_for(speech_chunk),
      position: speech_chunk.position,
      offset: speech_chunk.offset,
      text: speech_chunk.best_text,
      processing_status: speech_chunk.status,
      processed_stages_mask: speech_chunk.processed_stages.bits,
      response: speech_chunk.as_json,
      track_attributes: track_attributes
    }.tap do |h|
      h[:score] = speech_chunk.best_score if speech_chunk.best_score
    end

    result = if ingest_chunk.try(:id)
      CPW::Client::Base.try_request({logger: logger}) do
        ingest_chunk.update_attributes(chunk_attributes)
      end
    else
      CPW::Client::Base.try_request({logger: logger}) do
        Ingest::Chunk.create(chunk_attributes)
      end
    end

    sleep 1 # be nice :-)

    result
  end

  def add_speech_chunk_speaker_to_lsh_index(speech_chunk)
    # Note: The speech_chunk.speaker may be garbage collected due to
    # using threads with DRb. That's why we load the store GMM file
    # and add vector to the LSH.
    if lsh_index
      supervector_hash = speech_chunk.as_json.try(:[], 'speaker_segment').try(:[], 'speaker_supervector_hash')
      # get gmm file
      gmm_file_name = if speech_chunk.speaker_gmm_file_name
        speech_chunk.speaker_gmm_file_name
      elsif speaker_model_uri = speech_chunk.as_json.try(:[], 'speaker_segment').try(:[], 'speaker_model_uri')
        s3_download_object(bucket_name_from_s3_url(speaker_model_uri),
          key_from_s3_url(speaker_model_uri), speech_chunk.send(:chunk_speaker_gmm_file_name))
        speech_chunk.send(:chunk_speaker_gmm_file_name)
      end
      # add to lsh
      if supervector_hash.present? && !!gmm_file_name && File.exist?(gmm_file_name)
        if lsh_index.id_to_vector(supervector_hash.to_i)
          logger.info "****** chunk.speaker: found supervector hash `#{supervector_hash}` in LSH store `#{lsh_index.storage.class}`."
        else
          logger.info "****** chunk.speaker: add supervector hash `#{supervector_hash}` to LSH store `#{lsh_index.storage.class}`."
          speaker      = speech_chunk.splitter.diarize_load_speaker(gmm_file_name)
          supervector  = speaker.supervector
          vector       = GSL::Matrix.alloc(supervector.to_a, 1, supervector.dim)
          lsh_index.add(vector, supervector_hash.to_i)
        end
      end
    end
  end

  private

  def ingest_chunk_type_for(engine_or_speech_chunk)
    engine = if engine_or_speech_chunk.is_a?(CPW::Speech::Engines::SpeechEngine)
      engine_or_speech_chunk
    else
      engine_or_speech_chunk.engine
    end

    case engine.class.name
    when /GoogleCloudSpeechEngine/ then "Chunk::GoogleCloudSpeechChunk"
    when /NuanceDragonEngine/ then "Chunk::NuanceDragonChunk"
    when /PocketsphinxEngine/ then "Chunk::PocketsphinxChunk"
    when /SubtitleEngine/ then "Chunk::SubtitleChunk"
    when /VoicebaseEngine/ then "Chunk::VoiceBaseChunk"
    when /SpeechmaticsEngine/ then "Chunk::SpeechmaticsChunk"
    when /IbmWatsonSpeechEngine/ then "Chunk::IbmWatsonSpeechChunk"
    else
      raise ArgumentError, "unknown chunk type for #{speech_chunk.inspect}"
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

  def default_engine_options(options = {})
    {
      perform_threaded: false,
      split_method: :diarize,
      split_options: {
        mode: :druby,
        host: "localhost",
        port: 9999,
        model_base_url: s3_origin_ingest_base_url
      },
      extraction_engine: :ibm_watson_alchemy_engine,
      extraction_mode: [:media, :chunks],
      extraction_options: {
        include: {keyword_extraction: {emotion: true, sentiment: true}}
      },
      logger: logger,
      locale: ingest.locale,
      verbose: false
    }.merge(options)
  end
end
