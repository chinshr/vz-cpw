require_relative "test_helper"

class StoreTest < Test::Unit::TestCase # Minitest::Test
  def setup
    @store = CPW::Store.new("test-store.pstore")
  end

  def test_should_set_and_get
    @store.set(:test_set_get, "this is a test with set/get")
    assert_equal "this is a test with set/get", @store.get(:test_set_get)
  end

  def test_should_set_and_get_mixed_string_symbolic_keys
    @store.set("test_set_get_mixed", "this is a test with mixed")
    assert_equal "this is a test with mixed", @store.get(:test_set_get_mixed)
  end

  def test_should_set_and_get_with_array_operator
    @store[:test_operators] = "this is a test with operators"
    assert_equal "this is a test with operators", @store[:test_operators]
  end

  def test_should_fetch
    assert_equal "default", @store.fetch(:foo, "default")
  end

  def teardown
=begin
    @store.delete(:test_set_get)
    @store.delete(:test_operators)
    @store.delete(:test_set_get_mixed)
    @store.delete(:foo)
=end
    File.delete("#{CPW.root_path}/test-store.pstore")
  end
end