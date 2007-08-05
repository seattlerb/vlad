require 'test/unit'
require 'vlad'

class Vlad
  attr_accessor :commands
  def system(command)
    @commands << command
    true
  end
end

class TestVlad < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
    @vlad.reset
    @vlad.commands = []
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

  def test_run
    @vlad.host "app.example.com", :app
    @vlad.run("ls")
    assert_equal ["ssh app.example.com ls"], @vlad.commands
  end

  def test_run_with_no_hosts
    e = assert_raise(Vlad::ConfigurationError) { @vlad.run "ls" }
    assert_equal "No target hosts specified", e.message
  end

  def test_run_with_two_hosts
    @vlad.host "app.example.com", :app
    @vlad.host "db.example.com", :db
    @vlad.run("ls")

    commands = @vlad.commands

    assert commands.include?("ssh app.example.com ls")
    assert commands.include?("ssh db.example.com ls")
    assert_equal 2, commands.size
  end
end

