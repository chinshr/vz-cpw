require 'test_helper.rb'

class VersionTest < Test::Unit::TestCase

  def test_version
    assert_equal "2.2.1", CPW::VERSION
  end

end
