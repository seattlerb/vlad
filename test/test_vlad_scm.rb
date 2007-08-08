require 'test/vlad_test_case'
require 'vlad'
require 'vlad/scm'

class TestVladSCM < Test::Unit::TestCase
  def setup
    @scm = Vlad::SCM.new
  end

  def test_command
    cmd = @scm.command :export, "myproject"
    assert_equal "export myproject", cmd
  end

  def test_fetch
    set :some_var, 5
    assert_equal 5, @scm.fetch(:some_var)
  end
end
