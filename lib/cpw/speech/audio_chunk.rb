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

      attr_accessor :id, :splitter, :chunk, :flac_chunk, :wav_chunk, :raw_chunk, :mp3_chunk, :offset, :duration, :flac_rate, :copied,
        :captured_json, :best_text, :best_score, :status, :errors, :response

      def initialize(splitter, offset, duration, options = {})
        self.offset        = offset
        self.splitter      = splitter
        self.chunk         = chunk_file_name(splitter)
        self.duration      = duration
        self.id            = options[:id]
        self.response      = options[:response]
        self.copied        = false
        self.captured_json = {}
        self.best_text     = nil
        self.best_score    = nil
        self.status        = STATUS_UNPROCESSED
        self.errors        = []
      end

      def engine
        splitter.engine
      end

      def self.copy(splitter, id = nil)
        chunk        = AudioChunk.new(splitter, 0, splitter.duration.to_f, {id: id})
        chunk.status = STATUS_BUILT
        chunk.copied = true
        system("cp #{splitter.original_file} #{chunk.chunk}")
        chunk
      end

      # given the original file from the splitter and the chunked file name with duration and offset run the ffmpeg command
      def build
        return self if self.copied
        # ffmpeg -y -i sample.audio.wav -acodec copy -vcodec copy -ss 00:00:00.00 -t 00:00:30.00 sample.audio.out.wav
        offset_ts   = AudioInspector::Duration.from_seconds(self.offset).to_s
        duration_ts = AudioInspector::Duration.from_seconds(self.duration).to_s
        # NOTE: kind of a hack, but if the original source is less than or equal to 1 second, we should skip ffmpeg
        # logger.info "building chunk: #{duration_ts.inspect} and offset: #{offset_ts}"
        # logger.info "offset: #{ offset_ts.to_s }, duration: #{duration_ts.to_s}"
        # cmd = "ffmpeg -y -i #{splitter.original_file} -acodec copy -vcodec copy -ss #{offset_ts} -t #{duration_ts} #{self.chunk}   >/dev/null 2>&1"
        # cmd = "ffmpeg -y -i #{splitter.original_file} -acodec copy -vcodec copy -ss #{offset_ts} -t #{duration_ts} -f aiff #{self.chunk}   >/dev/null 2>&1"
        if base_audio_file_type == :raw
          cmd = "ffmpeg -y -i #{splitter.original_file} -f s16le -acodec pcm_s16le -vcodec copy -ss #{offset_ts} -t #{duration_ts} -ar 16000 -ac 1 #{self.chunk}   >/dev/null 2>&1"
        else
          cmd = "ffmpeg -y -i #{splitter.original_file} -acodec flac -vcodec copy -ss #{offset_ts} -t #{duration_ts} -f flac #{self.chunk}   >/dev/null 2>&1"
        end
        if system(cmd)
          self.status = STATUS_BUILT
          self
        else
          self.status = STATUS_BUILD_ERROR
          raise "Failed to generate chunk at offset: #{offset_ts}, duration: #{duration_ts}\n#{cmd}"
        end
      end

      # convert the audio file to flac format
      def to_flac
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
        if system("ffmpeg -i #{chunk} -acodec flac #{chunk_outputfile} >/dev/null 2>&1")
          self.flac_chunk = chunk.gsub(/#{File.extname(chunk)}$/, ".flac")
          # convert the audio file to 16K
          self.flac_rate = `ffmpeg -i #{self.flac_chunk} 2>&1`.strip.scan(/Audio: flac, (.*) Hz/).first.first.strip
          down_sampled = self.flac_chunk.gsub(/\.flac$/, '-sampled.flac')
          if system("ffmpeg -i #{self.flac_chunk} -ar 16000 -y #{down_sampled} >/dev/null 2>&1")
            system("mv #{down_sampled} #{self.flac_chunk} 2>&1 >/dev/null")
            self.flac_rate = 16000
            self.status    = STATUS_ENCODED
            self
          else
            self.status    = STATUS_ENCODING_ERROR
            raise "failed to convert to lower audio rate"
          end
        else
          self.status = STATUS_ENCODING_ERROR
          raise "failed to convert chunk: #{chunk} with flac #{chunk}"
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
            self.status    = STATUS_ENCODED
          else
            self.status    = STATUS_ENCODING_ERROR
            raise "failed to convert WAV to lower audio rate"
          end
        else
          self.status = STATUS_ENCODING_ERROR
          raise "failed to convert chunk: #{chunk} with WAV #{chunk}"
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
        if system("ffmpeg -i #{chunk} -y -f s16le -acodec pcm_s16le -ar 16000 -ac 1 #{chunk_outputfile}   >/dev/null 2>&1")
          self.raw_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = STATUS_ENCODED
        else
          self.status = STATUS_ENCODING_ERROR
          raise "failed to convert chunk: #{chunk} with RAW #{chunk}"
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
        options = options.merge({mp3_bitrate: 128})
        chunk_outputfile = chunk.gsub(/#{File.extname(chunk)}$/, ".#{options[:mp3_bitrate]}k.mp3")

        if system("ffmpeg -y -i #{chunk} -ar 16000 -vn -ab #{options[:mp3_bitrate]}k -f mp3 #{chunk_outputfile}   >/dev/null 2>&1")
          self.mp3_chunk = chunk_outputfile
          self.flac_rate = 16000
          self.status    = STATUS_ENCODED
        else
          self.status = STATUS_ENCODING_ERROR
          raise "failed to convert chunk: #{chunk} with WAV #{chunk}"
        end
        self
      end

      def to_mp3_bytes
        File.read(self.mp3_chunk)
      end

      def mp3_size
        File.size(self.mp3_chunk)
      end

      # delete the chunk file
      def clean
        File.unlink self.chunk if File.exist?(self.chunk)
        File.unlink self.flac_chunk if self.flac_chunk && File.exist?(self.flac_chunk)
        File.unlink self.wav_chunk if self.wav_chunk && File.exist?(self.wav_chunk)
        File.unlink self.raw_chunk if self.raw_chunk && File.exist?(self.raw_chunk)
        File.unlink self.mp3_chunk if self.mp3_chunk && File.exist?(self.mp3_chunk)
      end

      private

      # "abc123-chunk-1_51-a191.128k.mp3"
      def chunk_file_name(splitter)
        bf = splitter.basefolder || "/tmp"
        fn = File.basename(splitter.original_file)
        ex = File.extname(fn)
        fb = fn.gsub(/#{ex}$/, "")
        of = offset.to_s.gsub(/\./, "_")
        File.join(bf, fb + "-chunk-" + of + "-" + SecureRandom.hex(2) + ex)
      end

      def base_audio_file_type
        splitter.base_audio_file_type
      end

    end # AudioChunk
  end
end