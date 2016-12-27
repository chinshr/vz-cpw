module CPW
  module Speech
    module CommonHelper
      def self.included(base)
        base.include(InstanceMethods)
      end

      module InstanceMethods

        def keywords(min_relevance = 0.0)
          (as_json['keywords'] || []).map {|k| k['text'] if k['relevance'].to_f > min_relevance}.reject(&:blank?)
        end

      end # InstanceMethods
    end # CommonHelper
  end
end
