require_relative "test_helper"

class StoreTest < Minitest::Test
  def setup
    @store = CPW::Store.new
  end

  def test_should_set_and_get
    @store.set(:test_set_get, "this is a test with set/get")
    assert_equal "this is a test with set/get", @store.get(:test_set_get)
  end

  def test_should_set_and_get_with_array_operator
    @store[:test_operators] = "this is a test with operators"
    assert_equal "this is a test with operators", @store[:test_operators]
  end
end