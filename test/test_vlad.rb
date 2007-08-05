require 'test/unit'
require 'vlad'

class TestVlad < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
    @vlad.reset
  end

  def test_set
    @vlad.set :foo, 5
    assert_equal 5, @vlad.foo
  end

  def test_set_lazy_block_evaluation
    @vlad.set(:foo) { fail "lose" }
    assert_raise(RuntimeError) { @vlad.foo }
  end

  def test_set_with_block
    x = 1
    @vlad.set(:foo) { x += 2 }

    assert_equal 3, @vlad.foo
    assert_equal 3, @vlad.foo
  end

  def test_set_with_nil
    @vlad.set(:foo, nil)
    assert_equal nil, @vlad.foo
  end

  def test_role
    @vlad.role :app, "foo.example.com"
    expected = {"foo.example.com" => {}}
    assert_equal expected, @vlad.roles[:app]
  end

  def test_role_multiple_hosts
    @vlad.role :app, "foo.example.com"
    @vlad.role :app, "yarr.example.com", :no_release => true
    expected = {
      "foo.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }
    assert_equal expected, @vlad.roles[:app]
  end

  def test_role_multiple_roles
    @vlad.role :app, "foo.example.com", :primary => true
    @vlad.role :db, "yarr.example.com", :no_release => true
    expected_db = { "yarr.example.com" => {:no_release => true} }
    assert_equal expected_db, @vlad.roles[:db]
    expected_app = { "foo.example.com" => {:primary => true} }
    assert_equal expected_app, @vlad.roles[:app]
  end

  def test_host
    @vlad.host "foo.example.com", :app, :db
    expected = {"foo.example.com" => {}}
    assert_equal expected, @vlad.roles[:app]
    assert_equal expected, @vlad.roles[:db]
  end

  def test_host_multiple_hosts
    @vlad.host "foo.example.com", :app, :db
    @vlad.host "yarr.example.com", :app, :db, :no_release => true

    expected = {
      "foo.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }

    assert_equal expected, @vlad.roles[:app]
    assert_equal expected, @vlad.roles[:db]
    assert_not_equal(@vlad.roles[:db]["foo.example.com"].object_id,
                     @vlad.roles[:app]["foo.example.com"].object_id)
  end
end

