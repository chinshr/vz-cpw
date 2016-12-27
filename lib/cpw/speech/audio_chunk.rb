module CPW
  module Speech
    class AudioChunk
      include CPW::Speech::CommonHelper
      include ::Speech::Stages::ProcessHelper

      attr_accessor :position, :id, :splitter, :file_name, :flac_file_name, :wav_file_name, :raw_file_name,
        :mp3_file_name, :waveform_file_name, :offset, :duration, :flac_rate, :copied,
        :best_text, :best_score, :status, :errors, :speaker_segment, :bandwidth,
        :external_id, :poll_at, :raw_response, :normalized_response,
        :speaker_gmm_file_name
      attr_writer :words

      delegate :engine, to: :splitter, allow_nil: true
      delegate :base_file_type, to: :splitter, allow_nil: true
      delegate :source_file_type, to: :splitter, allow_nil: true

      alias_method :start_time, :offset
      alias_method :confidence, :best_score

      def initialize(splitter, offset, duration, options = {})
        self.offset              = offset
        self.splitter            = splitter
        self.duration            = duration
        self.position            = options[:position]
        self.id                  = options[:id]
        self.external_id         = options[:external_id]
        self.raw_response        = options[:raw_response] || {}
        self.normalized_response = options[:normalized_response] || {}
        self.copied              = false
        self.best_text           = nil
        self.best_score          = nil
        self.status              = ::Speech::State::STATUS_UNPROCESSED
        self.errors              = []
        self.file_name           = chunk_file_name(splitter)
        self.speaker_segment     = options[:speaker_segment]
        self.poll_at             = nil
      end

      class << self

        def copy(splitter, position = nil)
          chunk        = AudioChunk.new(splitter, 0, splitter.duration.to_f, {position: position})
          chunk.status = ::Speech::State::STATUS_PROCESSED
          chunk.processed_stages << :build
          chunk.copied = true
          system("cp #{splitter.original_file} #{chunk.file_name}")
          chunk
        end

        def build_from_ingest_chunk(splitter, ingest_chunk)
          audio_chunk = new(splitter, ingest_chunk.offset, ingest_chunk.duration, {
            position: ingest_chunk.position,
            id: ingest_chunk.id,
            normalized_response: ingest_chunk.response
          })
          # set
          audio_chunk.status           = ingest_chunk.processing_status
          audio_chunk.best_text        = ingest_chunk.text
          audio_chunk.best_score       = ingest_chunk.score
          audio_chunk.processed_stages = ingest_chunk.processed_stages
          # ...
          audio_chunk
        end
      end # class

      def id
        @id || position
      end

      def end_time
        offset + duration
      end

      def words
        @words || []
      end

      def as_json(options = {})
        normalized_response
      end

      def to_json(options = {})
        as_json(options).to_json
      end

      def to_text
        self.best_text
      end
      alias_method :to_s, :to_text

      def speaker
        speaker_segment.speaker if speaker_segment
      end

      # Build source file into source file type chunk.
      # Given the original file from the splitter and the chunked file name
      # with duration and offset run the ffmpeg command to build the source
      # file types chunk.
      def build(options = {})
        options = options.reverse_merge({source_file_type: source_file_type,
          base_file_type: base_file_type, source_file: splitter.original_file})
        return self if self.copied

        self.status = ::Speech::State::STATUS_PROCESSING
        self.processed_stages << :build

        offset_ts   = AudioInspector::Duration.from_seconds(self.offset).to_s
        duration_ts = AudioInspector::Duration.from_seconds(self.duration).to_s
        cmd         = "ffmpeg -y -i #{options[:source_file]} -acodec copy -vcodec copy -ss #{offset_ts} -t #{duration_ts} #{self.file_name}   >/dev/null 2>&1"

        # only build base audio file if needed
        if cmd
          if system(cmd)
            self.status = ::Speech::State::STATUS_PROCESSED
            self
          else
            self.status = ::Speech::State::STATUS_PROCESSING_ERROR
            raise BuildError, "Failed to chunk#build offset `#{offset_ts}`, duration `#{duration_ts}`\n#{cmd}"
          end
        end
      end

      # convert the audio file to flac format
      def to_flac
        chunk_outputfile = file_name.gsub(/#{File.extname(file_name)}$/, ".flac")
        self.status = ::Speech::State::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -y -i #{file_name} -acodec flac #{chunk_outputfile} >/dev/null 2>&1")
          self.flac_file_name = file_name.gsub(/#{File.extname(file_name)}$/, ".flac")
          # convert the audio file to 16K
          self.flac_rate = `ffmpeg -i #{self.flac_file_name} 2>&1`.strip.scan(/Audio: flac, (.*) Hz/).first.first.strip
          down_sampled = self.flac_file_name.gsub(/\.flac$/, '-sampled.flac')
          if system("ffmpeg -i #{self.flac_file_name} -ar 16000 -ac 1 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.flac_file_name} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = ::Speech::State::STATUS_PROCESSED
            self
          else
            self.status = ::Speech::State::STATUS_PROCESSING_ERROR
            raise "failed to audio encode to lower audio rate"
          end
        else
          self.status = ::Speech::State::STATUS_PROCESSING_ERROR
          raise EncodeError, "failed chunk#to_flac `#{file_name}`"
        end
        self
      end

      def to_flac_bytes
        File.read(self.flac_file_name)
      end

      def flac_size
        File.size(self.flac_file_name)
      end

      # convert the audio file to wav format
      def to_wav(options = {})
        chunk_outputfile = file_name.gsub(/#{File.extname(file_name)}$/, ".wav")
        self.status = ::Speech::State::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -i #{file_name} -y -f wav -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.wav_file_name = file_name.gsub(/#{File.extname(file_name)}$/, ".wav")
          # convert the audio file to 16K
          # self.flac_rate = `ffmpeg -i #{self.wav_file_name} 2>&1`.strip.scan(/Audio: wav, (.*) Hz/).first.first.strip
          down_sampled = self.wav_file_name.gsub(/\.wav$/, '-sampled.wav')
          if system("ffmpeg -i #{self.wav_file_name} -ar 16000 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.wav_file_name} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = ::Speech::State::STATUS_PROCESSED
          else
            self.status    = ::Speech::State::STATUS_PROCESSING_ERROR
            raise EncodeError, "failed chunk#to_wav lower audio rate `#{file_name}`"
          end
        else
          self.status      = ::Speech::State::STATUS_PROCESSING_ERROR
          raise EncodeError, "failed chunk#to_wav `#{file_name}`"
        end
        self
      end

      def to_wav_bytes
        File.read(self.wav_file_name)
      end

      def wav_size
        File.size(self.wav_file_name)
      end

      # convert the audio file to RAW format
      def to_raw(options = {})
        chunk_outputfile = file_name.gsub(/#{File.extname(file_name)}$/, ".raw")
        self.status = ::Speech::State::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -y -i #{file_name} -y -f s16le -acodec pcm_s16le -ar 16000 -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.raw_file_name = chunk_outputfile
          self.flac_rate = 16000
          self.status    = ::Speech::State::STATUS_PROCESSED
        else
          self.status = ::Speech::State::STATUS_PROCESSING_ERROR
          raise EncodeError, "failed chunk#to_raw `#{file_name}`"
        end
        self
      end

      def to_raw_bytes
        File.read(self.raw_file_name)
      end

      def raw_size
        File.size(self.raw_file_name)
      end

      # convert the audio file to mp3 format
      def to_mp3(options = {})
        options = options.reverse_merge({bitrate: 128, sample_rate: 16000})
        self.status = ::Speech::State::STATUS_PROCESSING
        self.processed_stages << :encode
        chunk_outputfile = file_name.gsub(/#{File.extname(file_name)}$/, ".ab#{options[:bitrate]}k.mp3")
        cmd = "ffmpeg -y -i #{file_name} -ar #{options[:sample_rate]} -vn -ab #{options[:bitrate]}K -f mp3 #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.mp3_file_name = chunk_outputfile
          self.flac_rate     = 16000
          self.status        = ::Speech::State::STATUS_PROCESSED
        else
          self.status = ::Speech::State::STATUS_PROCESSING_ERROR
          raise EncodeError, "failed chunk#to_mp3 `#{file_name}` with #{cmd}"
        end
        self
      end

      def to_mp3_bytes
        File.read(self.mp3_file_name)
      end

      def mp3_size
        File.size(self.mp3_file_name)
      end

      # convert the audio file to waveform json
      def to_waveform(options = {})
        options = options.reverse_merge({channels: ['left', 'right'],
          sampling_rate: 30, precision: 2})
        self.status      = ::Speech::State::STATUS_PROCESSING
        chunk_outputfile = file_name.gsub(/#{File.extname(file_name)}$/, ".waveform.json")
        channels         = [options[:channels]].flatten.map(&:split).flatten.join(' ')
        total_samples    = (duration.to_f * options[:sampling_rate]).to_i

        cmd = "wav2json #{file_name} --channels #{channels} --no-header --precision #{options[:precision]} --samples #{total_samples} -o #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.status             = ::Speech::State::STATUS_PROCESSED
          self.waveform_file_name = chunk_outputfile
        else
          self.status         = ::Speech::State::STATUS_PROCESSING_ERROR
          raise EncodeError, "failed chunk#to_waveform `#{file_name}` with `#{chunk_outputfile}` in #{cmd}"
        end
        self
      end

      # convert speaker segment to speaker gmm file
      def to_speaker_gmm
        if speaker_segment
          speaker_segment.speaker.save_model(chunk_speaker_gmm_file_name)
          self.speaker_gmm_file_name = chunk_speaker_gmm_file_name
        end
        self
      end

      # delete chunk file and all encoded files
      def clean
        File.unlink self.file_name if File.exist?(self.file_name)
        File.unlink self.flac_file_name if self.flac_file_name && File.exist?(self.flac_file_name)
        File.unlink self.wav_file_name if self.wav_file_name && File.exist?(self.wav_file_name)
        File.unlink self.raw_file_name if self.raw_file_name && File.exist?(self.raw_file_name)
        File.unlink self.mp3_file_name if self.mp3_file_name && File.exist?(self.mp3_file_name)
        File.unlink self.waveform_file_name if self.waveform_file_name && File.exist?(self.waveform_file_name)
        File.unlink self.speaker_gmm_file_name if self.speaker_gmm_file_name && File.exist?(self.speaker_gmm_file_name)
      end

      private

      # E.g. "/tmp/abc123-chunk-01-00+01_37-00+00+03_47.128k.mp3"
      def chunk_file_name(splitter_instance = splitter)
        bf = splitter_instance.basefolder || "/tmp"
        fn = File.basename(splitter_instance.original_file)
        ex = File.extname(fn)
        fb = fn.gsub(/#{ex}$/, "")
        of = AudioInspector::Duration.from_seconds(self.offset).to_s(:file)
        fo = AudioInspector::Duration.from_seconds(self.offset + self.duration).to_s(:file)
        File.join(bf, fb + "-chunk#{position ? "-#{position}" : ""}-" + of + "-" + fo + ex)
      end

      # E.g. "/tmp/abc123-chunk-01-speaker-S0.gmm"
      def chunk_speaker_gmm_file_name(splitter_instance = splitter)
        bf = splitter_instance.basefolder || "/tmp"
        fn = File.basename(splitter_instance.original_file)
        ex = File.extname(fn)
        fb = fn.gsub(/#{ex}$/, "")
        File.join(bf, fb + "-chunk#{position ? "-#{position}" : ""}-speaker-" + speaker_segment.speaker_id + ".gmm")
      end

    end # AudioChunk
  end
end
