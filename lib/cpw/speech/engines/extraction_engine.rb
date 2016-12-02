module CPW
  module Speech
    module Engines
      class ExtractionEngine
        attr_reader :speech_engine, :options

        def initialize(engine, options = {})
          @speech_engine = engine
          @options       = options
        end

        def extract(entity, options = {})
          raise NotImplementedError, "implement #convert in extraction engine."
        end

        protected

        def add_entity_error(entity, error, result = {})
          message = error.message.to_s.gsub(/\n|\r/, "")
          entity.errors.push(message)
          entity.normalized_response['errors'] = []unless entity.normalized_response['errors'].is_a?(Array)
          entity.normalized_response['errors'].push(message)
          result['errors'] = [] unless result['errors'].is_a?(Array)
          result['errors'].push(message)
          message
        end

      end # ExtractionEngine
    end
  end
end
