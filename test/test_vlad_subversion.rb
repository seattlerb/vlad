require 'vlad_test_case'
require 'vlad'
require 'vlad/subversion'

class TestVladSubversion < VladTestCase
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
    cmd = @scm.revision('HEAD')
    expected = "`svn info svn+ssh://repo/myproject | grep 'Revision:' | cut -f2 -d\\ `"
    assert_equal expected, cmd
  end
end
