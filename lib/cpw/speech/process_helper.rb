module CPW
  module Speech
    module ProcessHelper
      def self.included(base)
        base.send :attr_accessor, :processed_stages_proxy
        base.include(InstanceMethods)
      end

      class ProcessedStages
        include Enumerable

        PROCESSED_STAGES = {
          build: 2**0,
          encode: 2**1,
          convert: 2**2,
          extract: 2**3,
          split: 2**4,
          perform: 2**5
        }

        attr_accessor :bits

        def initialize(values = nil)
          @bits = 0
          set(values) if values
        end

        def self.bit_of(number)
          numbers = PROCESSED_STAGES.map {|k,v| number.is_a?(Fixnum) ? v : k}
          index   = numbers.index(number.is_a?(Fixnum) ? number : number.to_sym)
          index ? 2**index : 0
        end

        def set(values)
          new_keys  = ([values].flatten.map(&:to_sym) & PROCESSED_STAGES.keys)
          self.bits = new_keys.sum {|d| self.class.bit_of(d)}
          self
        end

        def get
          PROCESSED_STAGES.keys.reject {|d| ((bits || 0) & self.class.bit_of(d)).zero?}
        end
        alias_method :to_a, :get

        def add(values)
          combined_keys = (([values].flatten.map(&:to_sym) & PROCESSED_STAGES.keys) | get)
          self.bits = combined_keys.sum {|d| self.class.bit_of(d)}
        end
        alias_method :push, :add

        def <<(values)
          add(values)
        end

        def ==(other_object)
          if other_object.is_a?(self.class)
            get == other_object.get
          else
            get == ProcessedStages.new(other_object).get
          end
        end

        def each(&block)
          get.each {|stage| block.call(stage)}
        end

        def empty?
          get.empty?
        end

        def status
          bits
        end
      end # ProcessedStages

      module InstanceMethods

        def keywords(min_relevance = 0.0)
          (as_json['keywords'] || []).map {|k| k['text'] if k['relevance'].to_f > min_relevance}.reject(&:blank?)
        end

        def processed_stages=(values)
          self.processed_stages_proxy = if processed_stages_proxy
            processed_stages_proxy.set(values)
          else
            ProcessedStages.new(values)
          end
        end

        def processed_stages
          self.processed_stages_proxy ||= ProcessedStages.new
        end

        def unprocessed?
          processed_stages.empty?
        end

        def built?
          processed_stages.include?(:build)
        end

        def encoded?
          processed_stages.include?(:encode)
        end

        def converted?
          processed_stages.include?(:convert)
        end

        def extracted?
          processed_stages.include?(:extract)
        end

        def split?
          processed_stages.include?(:split)
        end

        def performed?
          processed_stages.include?(:perform)
        end

        def processing?
          raise CPW::Speech::NotImplementedError, "status not present" unless respond_to?(:status)
          status == CPW::Speech::STATUS_PROCESSING
        end

        def processed?
          raise CPW::Speech::NotImplementedError, "status not present" unless respond_to?(:status)
          status == CPW::Speech::STATUS_PROCESSED
        end

        def processing_error?
          raise CPW::Speech::NotImplementedError, "status not present" unless respond_to?(:status)
          status == CPW::Speech::STATUS_PROCESSING_ERROR
        end
      end # InstanceMethods
    end # ProcessHelper
  end
end
