module CPW
  module Speech
    class AudioChunk
      include CPW::Speech::ProcessHelper

      attr_accessor :position, :id, :splitter, :chunk, :flac_chunk, :wav_chunk, :raw_chunk,
        :mp3_chunk, :waveform_chunk, :offset, :duration, :flac_rate, :copied,
        :best_text, :best_score, :status, :errors, :speaker_segment, :bandwidth,
        :external_id, :poll_at, :raw_response, :normalized_response
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
        self.status              = CPW::Speech::STATUS_UNPROCESSED
        self.errors              = []
        self.chunk               = chunk_file_name(splitter)  # file_name?
        self.speaker_segment     = options[:speaker_segment]
        self.poll_at             = nil
      end

      class << self

        def copy(splitter, position = nil)
          chunk        = AudioChunk.new(splitter, 0, splitter.duration.to_f, {position: position})
          chunk.status = CPW::Speech::STATUS_PROCESSED
          chunk.processed_stages << :build
          chunk.copied = true
          system("cp #{splitter.original_file} #{chunk.chunk}")
          chunk
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

        self.status = CPW::Speech::STATUS_PROCESSING
        self.processed_stages << :build

        offset_ts   = AudioInspector::Duration.from_seconds(self.offset).to_s
        duration_ts = AudioInspector::Duration.from_seconds(self.duration).to_s
        cmd         = "ffmpeg -y -i #{options[:source_file]} -acodec copy -vcodec copy -ss #{offset_ts} -t #{duration_ts} #{self.chunk}   >/dev/null 2>&1"

        # only build base audio file if needed
        if cmd
          if system(cmd)
            self.status = CPW::Speech::STATUS_PROCESSED
            self
          else
            self.status = CPW::Speech::STATUS_PROCESSING_ERROR
            raise "Failed to build audio chunk at offset: #{offset_ts}, duration: #{duration_ts}\n#{cmd}"
          end
        end
      end

      # convert the audio file to flac format
      def to_flac
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
        self.status = CPW::Speech::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -y -i #{chunk} -acodec flac #{chunk_outputfile} >/dev/null 2>&1")
          self.flac_chunk = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
          # convert the audio file to 16K
          self.flac_rate = `ffmpeg -i #{self.flac_chunk} 2>&1`.strip.scan(/Audio: flac, (.*) Hz/).first.first.strip
          down_sampled = self.flac_chunk.gsub(/\.flac$/, '-sampled.flac')
          if system("ffmpeg -i #{self.flac_chunk} -ar 16000 -ac 1 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.flac_chunk} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = CPW::Speech::STATUS_PROCESSED
            self
          else
            self.status = CPW::Speech::STATUS_PROCESSING_ERROR
            raise "failed to audio encode to lower audio rate"
          end
        else
          self.status = CPW::Speech::STATUS_PROCESSING_ERROR
          raise "failed to audio encode chunk: #{chunk} with flac #{chunk}"
        end
        self
      end

      def to_flac_bytes
        File.read(self.flac_chunk)
      end

      def flac_size
        File.size(self.flac_chunk)
      end

      # convert the audio file to wav format
      def to_wav(options = {})
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".wav")
        self.status = CPW::Speech::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -i #{chunk} -y -f wav -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.wav_chunk = chunk.gsub(/#{File.extname(chunk)}$/, ".wav")
          # convert the audio file to 16K
          # self.flac_rate = `ffmpeg -i #{self.wav_chunk} 2>&1`.strip.scan(/Audio: wav, (.*) Hz/).first.first.strip
          down_sampled = self.wav_chunk.gsub(/\.wav$/, '-sampled.wav')
          if system("ffmpeg -i #{self.wav_chunk} -ar 16000 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.wav_chunk} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = CPW::Speech::STATUS_PROCESSED
          else
            self.status    = CPW::Speech::STATUS_PROCESSING_ERROR
            raise "failed to audio encode WAV to lower audio rate"
          end
        else
          self.status = CPW::Speech::STATUS_PROCESSING_ERROR
          raise "failed to audio encode chunk: #{chunk} with WAV #{chunk}"
        end
        self
      end

      def to_wav_bytes
        File.read(self.wav_chunk)
      end

      def wav_size
        File.size(self.wav_chunk)
      end

      # convert the audio file to RAW format
      def to_raw(options = {})
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".raw")
        self.status = CPW::Speech::STATUS_PROCESSING
        self.processed_stages << :encode
        if system("ffmpeg -y -i #{chunk} -y -f s16le -acodec pcm_s16le -ar 16000 -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.raw_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = CPW::Speech::STATUS_PROCESSED
        else
          self.status = CPW::Speech::STATUS_PROCESSING_ERROR
          raise "failed to audio encode chunk: #{chunk} with RAW #{chunk}"
        end
        self
      end

      def to_raw_bytes
        File.read(self.raw_chunk)
      end

      def raw_size
        File.size(self.raw_chunk)
      end

      # convert the audio file to mp3 format
      def to_mp3(options = {})
        options = options.reverse_merge({bitrate: 128, sample_rate: 16000})
        self.status = CPW::Speech::STATUS_PROCESSING
        self.processed_stages << :encode
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".ab#{options[:bitrate]}k.mp3")
        cmd = "ffmpeg -y -i #{chunk} -ar #{options[:sample_rate]} -vn -ab #{options[:bitrate]}K -f mp3 #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.mp3_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = CPW::Speech::STATUS_PROCESSED
        else
          self.status = CPW::Speech::STATUS_PROCESSING_ERROR
          raise "failed to convert chunk: #{chunk} to #{chunk_outputfile}: #{cmd}"
        end
        self
      end

      def to_mp3_bytes
        File.read(self.mp3_chunk)
      end

      def mp3_size
        File.size(self.mp3_chunk)
      end

      # convert the audio file to waveform json
      def to_waveform(options = {})
        options = options.reverse_merge({channels: ['left', 'right'],
          sampling_rate: 30, precision: 2})
        self.status      = CPW::Speech::STATUS_PROCESSING
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".waveform.json")
        channels         = [options[:channels]].flatten.map(&:split).flatten.join(' ')
        total_samples    = (duration.to_f * options[:sampling_rate]).to_i

        cmd = "wav2json #{chunk} --channels #{channels} --no-header --precision #{options[:precision]} --samples #{total_samples} -o #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.status         = CPW::Speech::STATUS_PROCESSED
          self.waveform_chunk = chunk_outputfile
        else
          self.status         = CPW::Speech::STATUS_PROCESSING_ERROR
          raise "failed to convert chunk #{chunk} to #{chunk_outputfile}: #{cmd}"
        end
        self
      end

      # delete the chunk file
      def clean
        File.unlink self.chunk if File.exist?(self.chunk)
        File.unlink self.flac_chunk if self.flac_chunk && File.exist?(self.flac_chunk)
        File.unlink self.wav_chunk if self.wav_chunk && File.exist?(self.wav_chunk)
        File.unlink self.raw_chunk if self.raw_chunk && File.exist?(self.raw_chunk)
        File.unlink self.mp3_chunk if self.mp3_chunk && File.exist?(self.mp3_chunk)
        File.unlink self.waveform_chunk if self.waveform_chunk && File.exist?(self.waveform_chunk)
      end

      private

      # "abc123-chunk-00+00+01_37-00+00+03_47.128k.mp3"
      def chunk_file_name(splitter)
        bf = splitter.basefolder || "/tmp"
        fn = File.basename(splitter.original_file)
        ex = File.extname(fn)
        fb = fn.gsub(/#{ex}$/, "")
        of = AudioInspector::Duration.from_seconds(self.offset).to_s(:file)
        fo = AudioInspector::Duration.from_seconds(self.offset + self.duration).to_s(:file)
        File.join(bf, fb + "-chunk#{id ? "-#{id}" : ""}-" + of + "-" + fo + ex)
      end
    end # AudioChunk
  end
end
