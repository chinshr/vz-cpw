module CPW
  module Speech
    class AudioToText
      attr_accessor :engine

      def initialize(file, options = {})
        engine_class = options.key?(:engine) ? "CPW::Speech::Engines::#{options[:engine].to_s.classify}".constantize : Engines::GoogleCloudSpeechEngine
        self.engine  = engine_class.new(file, options)
      end

      def perform(options = {}, &block)
        engine.perform(options, &block)
      end

      def to_text(options = {})
        engine.to_text(options)
      end
      alias_method :to_s, :to_text

      def as_json(options = {})
        engine.as_json(options)
      end

      def to_json(options = {})
        as_json(options).to_json
      end
    end
  end
end
