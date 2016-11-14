module CPW
  module Speech
    class AudioChunk::Word
      attr_accessor :sequence
      attr_accessor :start_time
      attr_accessor :end_time
      attr_accessor :confidence
      attr_accessor :word
      attr_accessor :error
      attr_accessor :metadata

      alias_method :position, :sequence
      alias_method :position=, :sequence=
      alias_method :p, :sequence
      alias_method :p=, :sequence=
      alias_method :c, :confidence
      alias_method :c=, :confidence=
      alias_method :s, :start_time
      alias_method :s=, :start_time=
      alias_method :e, :end_time
      alias_method :e=, :end_time=
      alias_method :w, :word
      alias_method :w=, :word=
      alias_method :m, :metadata
      alias_method :m=, :metadata=

      def initialize(options={})
        options.each do |k,v|
          self.send("#{k}=",v) if self.respond_to?("#{k}=")
        end
      end

      def clone
        clone = CPW::Speech::AudioChunk::Word.new
        clone.sequence   = sequence
        clone.start_time = start_time
        clone.end_time   = end_time
        clone.confidence = confidence
        clone.error      = error
        clone.word       = word
        clone.metadata   = metadata
        clone
      end

      def ==(word)
        self.sequence   == word.sequence &&
        self.start_time == word.start_time &&
        self.end_time   == word.end_time &&
        self.confidence == word.confidence &&
        self.word       == word.word &&
        self.metadata   == word.metadata
      end

      def empty?
        sequence.nil? && start_time.nil? && end_time.nil? && (word.nil? || word.empty?)
      end

      def to_hash
        {"p": sequence, "c": confidence, "s": start_time, "e": end_time, "w": word}
      end

      def to_json
        {"p": sequence, "c": confidence, "s": start_time, "e": end_time, "w": word}.to_json
      end
    end
  end
end
