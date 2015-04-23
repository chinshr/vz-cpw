module CPW
  class Server
    attr_accessor :threads

    def initialize
      @threads = []
      @terminate = false
    end

    def spawn
      Signal.trap("TERM") do
        terminate "TERM"
      end

      Signal.trap("SIGINT") do
        terminate "SIGINT"
      end

      threads << Thread.new { CPW::Worker::Harvest.new.run }
      threads << Thread.new { CPW::Worker::Transcode.new.run }
      threads.each {|t| t.join }
    end

    def terminate(signal = nil)
      puts signal if signal
      threads.each {|t| t.terminate }
    end
  end
end