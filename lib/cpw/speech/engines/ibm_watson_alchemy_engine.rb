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
          operations = extract_operations(options)
          unless operations.empty?
            operations.each do |operation, op_options|
              begin
                response = AlchemyAPI.search(operation,
                  op_options.merge({text: entity.to_text}))
                parse(operation, entity, response, result)
                entity.processed_stages << :extract
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

        def extract_operations(options = {})
          operations = {}
          if includes = options[:include]
            if includes.is_a?(Array)
              includes.each do |el|
                if el.is_a?(Array)
                  operations[el.first.to_sym] = el.last || {}
                else
                  operations[el.to_sym] = {}
                end
              end
            elsif includes.is_a?(Hash)
              includes.each {|k, v| operations[k.to_sym] = v.to_hash}
            elsif includes.is_a?(Symbol) || includes.is_a?(String)
              operations = {includes.to_sym => {}}
            end
          end
          # normalize boolean
          operations.each {|k, v|
            v.each {|ok, ov|
              if ov.is_a?(TrueClass)
                v[ok] = 1
              elsif ov.is_a?(FalseClass)
                v[ok] = 0
              end
            }
          }
          # done
          operations
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
