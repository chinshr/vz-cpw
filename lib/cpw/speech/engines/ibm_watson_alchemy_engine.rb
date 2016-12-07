module CPW
  module Speech
    module Engines
      class IbmWatsonAlchemyEngine < ExtractionEngine

        attr_accessor :api_key

        KNOWN_ERRORS = [
          AlchemyAPI::MissingOptionsError,
          AlchemyAPI::InvalidAPIKey,
          AlchemyAPI::InvalidSearchMode,
          AlchemyAPI::InvalidOutputMode,
          AlchemyAPI::UnknownError
        ]

        def initialize(speech_engine, options = {})
          super(speech_engine, options)

          self.api_key = options[:api_key] || ENV['IBM_WATSON_ALCHEMY_API_KEY']

          AlchemyAPI.configure do |config|
            config.apikey      = api_key
            config.output_mode = :json
          end
        end

        # {options: {include: :keyword_extraction}
        # {options: {include: [:keyword_extraction, {emotion: true}]}}
        # {options: {include: [[:keyword_extraction, {emotion: true}], :sentiment_analysis]}}
        def extract(entity, options = {})
          result, options = {}, self.options.merge(options)
          if options && options[:include]
            operations = [options[:include]].to_a.flatten
            operations.each do |operation|
              operation = [operation].to_a.flatten
              begin
                op         = operation[0]
                op_options = operation[1] || {}
                op_options.merge!(text: entity.to_text)
                if op
                  response = AlchemyAPI.search(op, op_options)
                  parse(op, entity, response, result)
                  entity.processed_stages << :extract
                end
              rescue *KNOWN_ERRORS => ex
                add_entity_error(entity, ex, result)
              end
            end
          end
          result
        end

        protected

        def parse(operation, entity, response, result)
          result[indexer(operation)] = entity.normalized_response[indexer(operation)] = response
          result
        end

        private

        def indexer(operation)
          case("#{operation}")
          when /keyword_extraction/i then "keywords"
          when /author_extraction/i then "authors"
          when /concept_tagging/i then "concepts"
          when /entity_extraction/i then "entities"
          when /relation_extraction/ then "relations"
          when /sentiment_analysis/, /:targeted_sentiment_analysis/ then "sentiments"
          when /taxonomy/ then "taxonomy"
          when /text_extraction/ then "text"
          when /title_extraction/ then "title"
          else
            raise UnknownOperationError, "no indexer available for `#{operation}`."
          end
        end
      end # IbmWatsonAlchemyEngine
    end
  end
end
