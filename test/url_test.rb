require "minitest/autorun"

require "cpw"

class UrlTest < Minitest::Test
  def test_url
    assert_equal "http://voyz.es/posts/ruby/1", CPW::Url
  end
end