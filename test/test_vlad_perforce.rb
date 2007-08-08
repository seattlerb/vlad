require 'test/vlad_test_case'
require 'vlad'
require 'vlad/perforce'

class TestVladPerforce < Test::Unit::TestCase
  def setup
    @scm = Vlad::Perforce.new
    set :repository, "/repo/myproject"
  end

  def test_checkout
    cmd = @scm.checkout 'head', '/the/place'
    assert_equal 'cd /repo/myproject && p4 sync ...#head && cp -rp . /the/place', cmd
  end

  def test_checkout_revision
    cmd = @scm.checkout 555, '/the/place'
    assert_equal 'cd /repo/myproject && p4 sync ...@555 && cp -rp . /the/place', cmd
  end

  def test_command
    cmd = @scm.command :export, "myproject"
    assert_equal "p4 export myproject", cmd
  end

  def test_export
    cmd = @scm.export 'head', '/the/place'
    assert_equal 'cd /repo/myproject && p4 sync ...#head && cp -rp . /the/place', cmd
  end
  
  def test_real_revision
    cmd = @scm.real_revision('head')
    assert_equal 'p4 changes -s submitted -m 1 ...#head | cut -f 2 -d\ ', cmd
  end

  def test_rev_no
    assert_equal "@555", @scm.rev_no(555)
    assert_equal "#head", @scm.rev_no('head')
    assert_equal "@666", @scm.rev_no("@666")
  end
end
