module CPW
  module Helper
    def self.included(base, *params)
      base.send :include, InstanceMethods
      base.send :extend, ClassMethods
    end

    module ClassMethods
    end

    module InstanceMethods
    end
  end
end