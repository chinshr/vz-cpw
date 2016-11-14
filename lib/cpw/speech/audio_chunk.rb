module CPW
  module Speech
    class AudioChunk
      STATUS_UNPROCESSED         = 0
      STATUS_BUILT               = 1
      STATUS_ENCODED             = 2
      STATUS_TRANSCRIBED         = 3
      STATUS_BUILD_ERROR         = -1
      STATUS_ENCODING_ERROR      = -2
      STATUS_TRANSCRIPTION_ERROR = -3

      attr_accessor :id, :splitter, :chunk, :flac_chunk, :wav_chunk, :raw_chunk,
        :mp3_chunk, :waveform_chunk, :offset, :duration, :flac_rate, :copied,
        :captured_json, :best_text, :best_score, :status, :errors, :response,
        :speaker, :bandwidth
      attr_writer :words

      delegate :engine, to: :splitter, allow_nil: true
      delegate :base_file_type, to: :splitter, allow_nil: true
      delegate :source_file_type, to: :splitter, allow_nil: true

      alias_method :position, :id
      alias_method :start_time, :offset
      alias_method :to_s, :best_text
      alias_method :confidence, :best_score

      def initialize(splitter, offset, duration, options = {})
        self.offset        = offset
        self.splitter      = splitter
        self.duration      = duration
        self.id            = options[:id]
        self.copied        = false
        self.captured_json = {}
        self.best_text     = nil
        self.best_score    = nil
        self.status        = STATUS_UNPROCESSED
        self.errors        = []
        self.response      = options[:response]
        self.chunk         = chunk_file_name(splitter)  # file_name?
        self.speaker       = options[:speaker]
        self.bandwidth     = options[:bandwidth]
      end

      class << self

        def copy(splitter, id = nil)
          chunk        = AudioChunk.new(splitter, 0, splitter.duration.to_f, {id: id})
          chunk.status = STATUS_BUILT if chunk.status < STATUS_BUILT
          chunk.copied = true
          system("cp #{splitter.original_file} #{chunk.chunk}")
          chunk
        end

      end

      def end_time
        offset + duration
      end

      def words
        @words || []
      end

      # Build source file into source file type chunk.
      # Given the original file from the splitter and the chunked file name
      # with duration and offset run the ffmpeg command to build the source
      # file types chunk.
      def build(options = {})
        options = options.reverse_merge({source_file_type: source_file_type,
          base_file_type: base_file_type, source_file: splitter.original_file})
        return self if self.copied

        offset_ts   = AudioInspector::Duration.from_seconds(self.offset).to_s
        duration_ts = AudioInspector::Duration.from_seconds(self.duration).to_s
        # cmd         = nil
        # if options[:base_file_type] == :raw &&
        #   options[:base_file_type] != options[:source_file_type]
        #   # source file wav
        #   cmd = "ffmpeg -y -i #{options[:source_file]} -f s16le -acodec pcm_s16le -vcodec copy -ss #{offset_ts} -t #{duration_ts} -ar 16000 -ac 1 #{self.chunk}   >/dev/null 2>&1"
        # elsif options[:base_file_type] == :flac &&
        #   options[:base_file_type] != options[:source_file_type]
        #   cmd = "ffmpeg -y -i #{options[:source_file]} -acodec flac -vcodec copy -ss #{offset_ts} -t #{duration_ts} -f flac #{self.chunk}   >/dev/null 2>&1"
        # elsif options[:base_file_type] == :wav &&
        #   options[:base_file_type] != options[:source_file_type]
        #   cmd = "ffmpeg -y -i #{options[:source_file]} -f wav -vcodec copy -ss #{offset_ts} -t #{duration_ts} #{self.chunk}   >/dev/null 2>&1"
        # end
        cmd = "ffmpeg -y -i #{options[:source_file]} -acodec copy -vcodec copy -ss #{offset_ts} -t #{duration_ts} #{self.chunk}   >/dev/null 2>&1"

        # only build base audio file if needed
        if cmd
          if system(cmd)
            self.status = STATUS_BUILT if self.status < STATUS_BUILT
            self
          else
            self.status = STATUS_BUILD_ERROR
            raise "Failed to build audio chunk at offset: #{offset_ts}, duration: #{duration_ts}\n#{cmd}"
          end
        end
      end

      # convert the audio file to flac format
      def to_flac
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
        if system("ffmpeg -y -i #{chunk} -acodec flac #{chunk_outputfile} >/dev/null 2>&1")
          self.flac_chunk = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
          # convert the audio file to 16K
          self.flac_rate = `ffmpeg -i #{self.flac_chunk} 2>&1`.strip.scan(/Audio: flac, (.*) Hz/).first.first.strip
          down_sampled = self.flac_chunk.gsub(/\.flac$/, '-sampled.flac')
          if system("ffmpeg -i #{self.flac_chunk} -ar 16000 -ac 1 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.flac_chunk} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = STATUS_ENCODED if self.status < STATUS_ENCODED
            self
          else
            self.status = STATUS_ENCODING_ERROR
            raise "failed to audio encode to lower audio rate"
          end
        else
          self.status = STATUS_ENCODING_ERROR
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
        if system("ffmpeg -i #{chunk} -y -f wav -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.wav_chunk = chunk.gsub(/#{File.extname(chunk)}$/, ".wav")
          # convert the audio file to 16K
          # self.flac_rate = `ffmpeg -i #{self.wav_chunk} 2>&1`.strip.scan(/Audio: wav, (.*) Hz/).first.first.strip
          down_sampled = self.wav_chunk.gsub(/\.wav$/, '-sampled.wav')
          if system("ffmpeg -i #{self.wav_chunk} -ar 16000 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.wav_chunk} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = STATUS_ENCODED if self.status < STATUS_ENCODED
          else
            self.status    = STATUS_ENCODING_ERROR
            raise "failed to audio encode WAV to lower audio rate"
          end
        else
          self.status = STATUS_ENCODING_ERROR
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
        if system("ffmpeg -y -i #{chunk} -y -f s16le -acodec pcm_s16le -ar 16000 -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.raw_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = STATUS_ENCODED if self.status < STATUS_ENCODED
        else
          self.status = STATUS_ENCODING_ERROR
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
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".ab#{options[:bitrate]}k.mp3")
        cmd = "ffmpeg -y -i #{chunk} -ar #{options[:sample_rate]} -vn -ab #{options[:bitrate]}K -f mp3 #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.mp3_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = STATUS_ENCODED if self.status < STATUS_ENCODED
        else
          self.status = STATUS_ENCODING_ERROR
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
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".waveform.json")
        channels         = [options[:channels]].flatten.map(&:split).flatten.join(' ')
        total_samples    = (duration.to_f * options[:sampling_rate]).to_i

        cmd = "wav2json #{chunk} --channels #{channels} --no-header --precision #{options[:precision]} --samples #{total_samples} -o #{chunk_outputfile}   >/dev/null 2>&1"
        if system(cmd)
          self.waveform_chunk = chunk_outputfile
        else
          self.status = STATUS_ENCODING_ERROR
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
