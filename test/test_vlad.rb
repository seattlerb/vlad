require 'test/unit'
require 'vlad'

class Vlad
  attr_accessor :commands, :action
  def system(command)
    @commands << command
    self.action ? self.action[command] : true
  end
end

class TestVlad < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
    @vlad.reset
    @vlad.commands = []
    @vlad.action = nil
  end

  def test_all_hosts
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.all_hosts
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

  def test_set_with_block_and_value
    e = assert_raise(ArgumentError) do
      @vlad.set(:foo, 5) { 6 }
    end
    assert_equal "cannot provide both a value and a block", e.message
  end

  def test_set_with_nil
    @vlad.set(:foo, nil)
    assert_equal nil, @vlad.foo
  end

  def test_set_with_reserved_name
    e = assert_raise(ArgumentError) { @vlad.set(:all_hosts, []) }
    assert_equal "cannot set reserved name: 'all_hosts'", e.message
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
    util_set_hosts
    @vlad.target_hosts = @vlad.hosts_for_role(:app)
    @vlad.run("ls")
    assert_equal ["ssh app.example.com ls"], @vlad.commands
  end

  def test_run_failing_command
    util_set_hosts
    @vlad.target_hosts = %[app.example.com]
    @vlad.action = lambda { false }
    assert_raise(Vlad::CommandFailedError) { @vlad.run("ls") }
    assert_equal 1, @vlad.commands.size
  end

  def test_run_with_no_hosts
    util_set_hosts
    e = assert_raise(Vlad::ConfigurationError) { @vlad.run "ls" }
    assert_equal "No target hosts specified", e.message
  end

  def test_run_with_no_roles
    e = assert_raise(Vlad::ConfigurationError) { @vlad.run "ls" }
    assert_equal "No roles have been defined", e.message
  end

  def test_run_with_two_hosts
    util_set_hosts
    @vlad.target_hosts = @vlad.all_hosts
    @vlad.run("ls")

    commands = @vlad.commands

    assert_equal 2, commands.size, 'not enough commands'
    assert commands.include?("ssh app.example.com ls"), 'app'
    assert commands.include?("ssh db.example.com ls"), 'db'
  end

  def test_hosts_for_role
    util_set_hosts
    assert_equal ["app.example.com"], @vlad.hosts_for_role(:app)
  end

  def test_target_hosts
    util_set_hosts
    assert_equal nil, @vlad.target_hosts
    @vlad.target_hosts = ["app.example.com"]
    assert_equal ["app.example.com"], @vlad.target_hosts
  end

  def util_set_hosts
    @vlad.host "app.example.com", :app
    @vlad.host "db.example.com", :db
  end
end

