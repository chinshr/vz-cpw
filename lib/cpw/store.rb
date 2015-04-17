module CPW
  class Store
    def initialize(name = nil)
      @store = PStore.new(name || "cpw.pstore")
    end

    def get(key)
      @store.transaction do
        @store[key.to_s]
      end
    end
    alias_method :[], :get

    def set(key, value)
      @store.transaction do
        @store[key.to_s] =  value
      end
    end
    alias_method :[]=, :set

    def fetch(key, default)
      @store.transaction do
        @store.fetch(key.to_s, default)
      end
    end

    def delete(key)
      @store.transaction do
        @store.delete(key.to_s)
      end
    end
  end
end