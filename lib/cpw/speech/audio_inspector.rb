module CPW
  module Speech
    class AudioInspector
      attr_accessor :duration

      class Duration
        attr_accessor :hours, :minutes, :seconds, :total_seconds

        def initialize(duration_str)
          self.hours, self.minutes, self.seconds = duration_str.try(:split, ':')
          self.total_seconds = (self.hours.to_i * 3600) + (self.minutes.to_i * 60) + self.seconds.to_f
        end

        # 00:00:01.37
        def to_s(format = nil)
          format = (format == :file) ? "%.2d-%.2d-%.2d_%.2d" : (format || "%.2d:%.2d:%.2d.%.2d")
          s, f   = seconds.split('.')
          sprintf format, self.hours.to_i, self.minutes.to_i, s.to_i, (f||0).to_i
        end

        # 00+00+01_37
        def to_file_s
          to_s.gsub(/\./, "_").gsub(/\:/, "+")
        end

        def to_f
          (self.hours.to_i * 3600) + (self.minutes.to_i * 60) + self.seconds.to_f
        end

        def self.from_seconds(seconds)
          duration = Duration.new("00:00:00.00")
          duration.hours = (seconds.to_i / 3600).to_i
          duration.minutes = ((seconds.to_i - (duration.hours*3600)) / 60).to_i
          secs = (seconds - (duration.minutes*60) - (duration.hours*3600))
          duration.seconds = sprintf("%.2f", secs)
          duration.hours = duration.hours.to_s
          duration.minutes = duration.minutes.to_s

          duration
        end

        def +(b)
          total = self.to_f + b.to_f
          Duration.from_seconds(self.to_f + b.to_f)
        end

      end

      def initialize(file)
        out = `ffmpeg -i #{file} 2>&1`.strip
        if out.match(/No such file or directory/)
          raise "No such file or directory: #{file}"
        else
          out = out.scan(/Duration: (.*),/)
          self.duration = Duration.new(out.try(:first).try(:first))
        end
      end

    end
  end
end