require_relative "test_helper"

class WorkerTest < Test::Unit::TestCase
  def test_stage_name
    assert_equal "split", CPW::Worker::Split.stage_name
  end

  def test_queue_name
    assert_equal "SPLIT_TEST_QUEUE", CPW::Worker::Split.queue_name
  end

  def test_class_for
    assert_equal CPW::Worker::Finish, CPW::Worker::Base.class_for("finish")
    assert_equal CPW::Worker::Finish, CPW::Worker::Base.class_for("finish.rb")
  end
end