module CPW
  module Speech
    module Engines
      class SpeechmaticsEngine::Speaker
        attr_accessor :error
        attr_accessor :words
        attr_accessor :sequence

        attr_accessor :duration
        attr_accessor :confidence
        attr_accessor :name
        attr_accessor :time

        alias_method :position, :sequence
        alias_method :position=, :sequence=
        alias_method :start_time, :time
        alias_method :start_time=, :time=

        class << self
          def required_keys
            %w(duration name time)
          end
        end

        def initialize(attributes = {})
          attributes.each do |k,v|
            self.send("#{k}=",v) if self.respond_to?("#{k}=")
          end
          convert
          validate
        end

        def valid?
          !@error
        end

        def end_time
          @end_time ? @end_time : (start_time + duration)
        end

        def ==(speaker)
          self.duration   == speaker.duration &&
          self.confidence == speaker.confidence &&
          self.name       == speaker.name &&
          self.time       == speaker.time
        end

        def empty?
          duration.nil? && confidence.nil? && (name.nil? || name.empty?) && time.nil?
        end

        def as_json
          {"duration": duration, "confidence": confidence, "name": name, "time": time}
        end
        alias_method :to_hash, :as_json

        def to_json
          as_json.to_json
        end

        protected

        def convert
          self.duration   = duration.to_f if duration
          self.confidence = confidence.to_f if confidence
          self.time       = time.to_f if time
        end

        def validate
          SpeechmaticsEngine::Speaker.required_keys.each do |key|
            if self.send(key).nil?
              self.error = "Invalid formatting of #{key}, #{self.to_json.inspect}"
            end
          end
        end

      end # SpeechmaticsEngine::Speaker
    end # Engines
  end # Speech
end # CPW
