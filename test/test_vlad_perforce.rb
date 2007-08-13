require 'test/vlad_test_case'
require 'vlad'
require 'vlad/perforce'

class TestVladPerforce < VladTestCase
  def setup
    super
    @scm = Vlad::Perforce.new

    Vlad::Perforce.reset
    set :repository, "/repo/myproject"
    set :p4user, "user"
    set :p4pass, "password"
    set :application, "application"
  end

  def test_checkout
    cmd = @scm.checkout 'head', '/the/place'
    assert_equal 'p4 -p localhost:1666 -u user -P password -c user-application sync ...#head', cmd
  end

  def test_checkout_revision
    cmd = @scm.checkout 555, '/the/place'
    assert_equal 'p4 -p localhost:1666 -u user -P password -c user-application sync ...@555', cmd
  end

  def test_export
    cmd = @scm.export 'head', '/the/place'
    assert_equal '(cd /the/place && p4 -p localhost:1666 -u user -P password -c user-application sync ...#head)', cmd
  end
  
  def test_revision
    cmd = @scm.revision('head')
    assert_equal '`p4 -p localhost:1666 -u user -P password -c user-application changes -s submitted -m 1 ...#head | cut -f 2 -d\\ `', cmd
  end

  def test_rev_no
    assert_equal "@555", @scm.rev_no(555)
    assert_equal "#head", @scm.rev_no('head')
    assert_equal "#head", @scm.rev_no('HEAD')
    assert_equal "@666", @scm.rev_no("@666")
  end
end
