require 'test_helper.rb'

class Ingest::WorkerTest < Test::Unit::TestCase
  setup do
    @worker = Ingest::Worker.new(attributes: {"state": "foo", "lock_count": 1})
  end

  def test_lock_count
    assert_equal 1, @worker.lock_count
  end

  def test_state
    assert_equal :foo, @worker.state
  end
end
