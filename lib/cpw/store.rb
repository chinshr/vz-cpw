module CPW
  class Store
    def initialize
      @store = PStore.new("cpw.pstore")
    end

    def get(key)
      @store.transaction do
        @store[key]
      end
    end
    alias_method :[], :get

    def set(key, value)
      @store.transaction do
        @store[key] =  value
      end
    end
    alias_method :[]=, :set
  end
end