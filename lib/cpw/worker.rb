module CPW
  class Worker
    def initialize
      @terminate = false
    end

    def run
      at_exit do
        stop "at_exit"
      end

      while !@terminate
        puts "working #{self.class.name}...\n"
        sleep 1
      end
    end

    def start
    end

    def stop(signal = nil)
      @terminate = true
      $stderr.puts("'#{signal}' received for #{self.class.name}, stopping thread loop.")
    end
  end
end