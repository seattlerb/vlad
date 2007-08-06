require 'test/vlad_test_case'
require 'vlad'

class TestVlad < VladTestCase
  def test_all_hosts
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.all_hosts
  end

  def test_host
    @vlad.host "test.example.com", :app, :db
    expected = {"test.example.com" => {}}
    assert_equal expected, @vlad.roles[:app]
    assert_equal expected, @vlad.roles[:db]
  end

  def test_host_multiple_hosts
    @vlad.host "test.example.com", :app, :db
    @vlad.host "yarr.example.com", :app, :db, :no_release => true

    expected = {
      "test.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }

    assert_equal expected, @vlad.roles[:app]
    assert_equal expected, @vlad.roles[:db]
    assert_not_equal(@vlad.roles[:db]["test.example.com"].object_id,
                     @vlad.roles[:app]["test.example.com"].object_id)
  end

  def test_hosts_for_one_role
    util_set_hosts
    @vlad.host "app2.example.com", :app
    assert_equal %w[app.example.com app2.example.com], @vlad.hosts_for(:app)
  end

  def test_hosts_for_multiple_roles
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.hosts_for(:app, :db)
  end

  def test_hosts_for_array_of_roles
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.hosts_for([:app, :db])
  end

  def test_initialize
    assert_raise(Vlad::ConfigurationError) { @vlad.application }
    assert_raise(Vlad::ConfigurationError) { @vlad.repository }
  end

  def test_role
    @vlad.role :app, "test.example.com"
    expected = {"test.example.com" => {}}
    assert_equal expected, @vlad.roles[:app]
  end

  def test_role_multiple_hosts
    @vlad.role :app, "test.example.com"
    @vlad.role :app, "yarr.example.com", :no_release => true
    expected = {
      "test.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }
    assert_equal expected, @vlad.roles[:app]
  end

  def test_role_multiple_roles
    @vlad.role :app, "test.example.com", :primary => true
    @vlad.role :db, "yarr.example.com", :no_release => true
    expected_db = { "yarr.example.com" => {:no_release => true} }
    assert_equal expected_db, @vlad.roles[:db]
    expected_app = { "test.example.com" => {:primary => true} }
    assert_equal expected_app, @vlad.roles[:app]
  end

  def test_set
    @vlad.set :test, 5
    assert_equal 5, @vlad.test
  end

  def test_set_lazy_block_evaluation
    @vlad.set(:test) { fail "lose" }
    assert_raise(RuntimeError) { @vlad.test }
  end

  def test_set_with_block
    x = 1
    @vlad.set(:test) { x += 2 }

    assert_equal 3, @vlad.test
    assert_equal 3, @vlad.test
  end

  def test_set_with_block_and_value
    e = assert_raise(ArgumentError) do
      @vlad.set(:test, 5) { 6 }
    end
    assert_equal "cannot provide both a value and a block", e.message
  end

  def test_set_with_nil
    @vlad.set(:test, nil)
    assert_equal nil, @vlad.test
  end

  def test_set_with_reserved_name
    e = assert_raise(ArgumentError) { @vlad.set(:all_hosts, []) }
    assert_equal "cannot set reserved name: 'all_hosts'", e.message
  end

  def test_remote_task
    t = @vlad.remote_task(:test_task) { 5 }
    assert_equal @task_count + 1, Rake.application.tasks.size
    assert_equal Hash.new, t.options
  end

  def test_remote_task_all_hosts_by_default
    util_set_hosts
    t = @vlad.remote_task(:test_task) { 5 }
    assert_equal %w[app.example.com db.example.com], t.target_hosts
  end

  def test_remote_task_self
    @vlad.instance_eval "host 'www.example.com', :role => 'app'"
    @vlad.instance_eval "remote_task(:self_task) do $self_task_result = self end"

    task = Rake::Task['self_task']
    task.execute
    assert_equal task, $self_task_result
  end

  def test_remote_task_body_set
    @vlad.set(:some_variable, 5)
    @vlad.instance_eval "host 'www.example.com', :role => 'app'"
    @vlad.instance_eval "remote_task(:some_task) do $some_task_result = some_variable end"

    Rake::Task['some_task'].execute
    assert_equal @vlad.fetch(:some_variable), $some_task_result
  end

  def test_remote_task_with_options
    t = @vlad.remote_task :test_task, :roles => [:app, :db] do
      fail "should not run"
    end
    assert_equal({:roles => [:app, :db]}, t.options)
  end

end

