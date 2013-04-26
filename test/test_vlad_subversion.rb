require 'vlad'
require 'vlad/subversion'

class TestVladSubversion < MiniTest::Unit::TestCase
  def setup
    super
    @scm = Vlad::Subversion.new
    set :repository, "svn+ssh://repo/myproject"
  end

  def test_checkout
    cmd = @scm.checkout 'HEAD', '/the/place'
    assert_equal 'svn co -r HEAD svn+ssh://repo/myproject /the/place', cmd
  end

  def test_export
    cmd = @scm.export 'HEAD', '/the/place'
    assert_equal 'svn export -r HEAD svn+ssh://repo/myproject /the/place', cmd
  end

  def test_revision
    cmd = @scm.revision
    assert_equal "HEAD", cmd
  end

  def test_set_defaults
    [source, svn_cmd, revision].each { |var| assert var }
  end
end
