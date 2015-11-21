ENV['CPW_ENV'] = "test"
require "rubygems"
require "test/unit"
# require "minitest/autorun"
require "byebug"
require "cpw"
require "mocha/test_unit"
# require "mocha/mini_test"
require "webmock/test_unit"
# require "webmock/minitest"

# Require support files
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

class Test::Unit::TestCase

  # Add global extensions to the test case class here

  # E.g. "/Users/foo/work/test"
  def test_root
    File.dirname(__FILE__)
  end

  def fixtures_root
    "#{test_root}/fixtures"
  end
end
