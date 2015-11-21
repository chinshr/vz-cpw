require 'test_helper.rb'

class CPWTest < Test::Unit::TestCase # Minitest::Test

  def test_env
    assert_equal "test", CPW.env
  end

  def test_root_path
    assert_equal "vz-cpw", CPW.root_path.split("/").last
  end

  def test_lib_path
    assert_equal "lib", CPW.lib_path.split("/").last
  end

  def test_models_root_path
    assert_equal "vz-models", CPW.models_root_path.split("/").last
  end

  def test_base_url
    assert_equal "http://www.example.com/api/", CPW.base_url
  end

end