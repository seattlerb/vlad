require 'test/vlad_test_case'
require 'vlad'
require 'vlad/mercurial'

class TestVladMercurial < Test::Unit::TestCase
  def setup
    @scm = Vlad::Mercurial.new
    set :repository, "http://repo/project"
  end

  def test_checkout
    cmd = @scm.checkout 'head', '/the/place'

    expected = "if [ ! -d /the/place/.hg ]; then hg init -R /the/place; fi " \
               "&& hg pull -r tip -R /the/place http://repo/project"

    assert_equal expected, cmd
  end

  def test_export
    cmd = @scm.export 'head', '/the/place'
    assert_equal 'hg archive -r tip -R http://repo/project /the/place', cmd
  end

  def test_revision
    cmd = @scm.revision('tip')
    expected = "`hg identify -R http://repo/project | cut -f1 -d\\ `"
    assert_equal expected, cmd
  end
end

