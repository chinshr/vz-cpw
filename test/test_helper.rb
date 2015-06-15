ENV['CPW_ENV'] = 'test'

require "test/unit"
# require "minitest/autorun"
require "cpw"
require 'mocha/test_unit'
# require 'mocha/mini_test'
require 'webmock/test_unit'
# require 'webmock/minitest'
require 'byebug'

# Require support files
Dir[File.expand_path('../support/**/*.rb', __FILE__)].each { |f| require f }

class Test::Unit::TestCase

  # Add global extensions to the test case class here

end
