module CPW
  class Server
    attr_accessor :threads
    attr_reader :logger

    def initialize
      @threads   = []
      @terminate = false
      @logger    = CPW::logger
    end

    def spawn
      logger.info "Starting server..."
      Signal.trap("TERM") do
        terminate "TERM"
      end

      Signal.trap("SIGINT") do
        terminate "SIGINT"
      end

      CPW::Worker.subclasses.each do |worker_class|
        threads << Thread.new { worker_class.new.run }
      end
      threads.each {|t| t.join }
    end

    def terminate(signal = nil)
      logger.info "\nStopping server...(#{signal})"
      threads.each {|t| t.terminate }
      while threads.any? {|t| t.alive? }
      end
      logger.info "\nStopped."
    end
  end
end