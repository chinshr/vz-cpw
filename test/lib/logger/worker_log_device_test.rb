require 'test_helper.rb'

class CPW::Logger::WorkerLogDeviceTest < Test::Unit::TestCase

  def setup
    @worker = CPW::Worker::Base.new
  end

  def test_initialize
    dev = CPW::Logger::WorkerLogDevice.new(@worker)
    assert_equal @worker, dev.worker
  end

  def test_simple_logger
    logger = ::Logger.new(CPW::Logger::WorkerLogDevice.new(@worker))
    assert logger.info("test_info")
    assert_equal 1, @worker.logger_messages.size
    assert_equal true, @worker.logger_messages[0].include?("test_info")
  end

  def test_with_multi_logger
    mono_logger = MonoLogger.new(STDOUT)
    worker_logger = ::Logger.new(CPW::Logger::WorkerLogDevice.new(@worker))
    logger = CPW::Logger::MultiLogger.new(mono_logger, worker_logger)
    assert logger.info("test_info")
    assert_equal 1, @worker.logger_messages.size
    assert_equal true, @worker.logger_messages[0].include?("test_info")
  end

end
