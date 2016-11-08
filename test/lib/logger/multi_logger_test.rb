require 'test_helper.rb'

class CPW::Logger::MultiLoggerTest < Test::Unit::TestCase

  def setup
    @stdout_logger = ::Logger.new($stdout)
  end

  def test_initialize
    logger = CPW::Logger::MultiLogger.new(@stdout_logger)
    assert_not_empty logger.targets
  end

  def test_initialize_multi
    logger = CPW::Logger::MultiLogger.new(::Logger.new(STDERR), ::Logger.new(STDOUT))
    assert_equal 2, logger.targets.size
  end

  def test_log_info
    assert multi_logger.info("test info")
  end

  def test_log_error
    assert multi_logger.error("test error")
  end

  protected

  def multi_logger
    CPW::Logger::MultiLogger.new(@stdout_logger)
  end
end
