require 'rake/test_case'

$TESTING = true

class TestVlad < Rake::TestCase
  def test_all_hosts
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @rake.all_hosts
  end

  def test_fetch
    set :foo, 5
    assert_equal 5, @rake.fetch(:foo)
  end

  def test_fetch_with_default
    assert_equal 5, @rake.fetch(:not_here, 5)
  end

  def test_fetch_rails
    # verifies that the rails environment was properly refactored
    assert_equal "production", @rake.fetch(:rails_env, nil)
  end

  def test_host
    @rake.host "test.example.com", :app, :db
    expected = {"test.example.com" => {}}
    assert_equal expected, @rake.roles[:app]
    assert_equal expected, @rake.roles[:db]
  end

  def test_host_invalid
    assert_raises(ArgumentError) { @rake.host nil, :web }
  end

  def test_host_multiple_hosts
    @rake.host "test.example.com", :app, :db
    @rake.host "yarr.example.com", :app, :db, :no_release => true

    expected = {
      "test.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }

    assert_equal expected, @rake.roles[:app]
    assert_equal expected, @rake.roles[:db]
    refute_equal(@rake.roles[:db]["test.example.com"].object_id,
                 @rake.roles[:app]["test.example.com"].object_id)
  end

  def test_hosts_for_array_of_roles
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @rake.hosts_for([:app, :db])
  end

  def test_hosts_for_one_role
    util_set_hosts
    @rake.host "app2.example.com", :app
    assert_equal %w[app.example.com app2.example.com], @rake.hosts_for(:app)
  end

  def test_hosts_for_multiple_roles
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @rake.hosts_for(:app, :db)
  end

  def test_hosts_for_unique
    util_set_hosts
    @rake.host "app.example.com", :web
    assert_equal %w[app.example.com db.example.com], @rake.hosts_for(:app, :db, :web)
  end

  def test_initialize
    @rake.set_defaults # ensure these three are virginal
    assert_raises(Rake::ConfigurationError) { @rake.repository }
    assert_raises(Rake::ConfigurationError) { @rake.deploy_to }
    assert_raises(Rake::ConfigurationError) { @rake.domain }
  end

  def test_role
    @rake.role :app, "test.example.com"
    expected = {"test.example.com" => {}}
    assert_equal expected, @rake.roles[:app]
  end

  def test_role_multiple_hosts
    @rake.role :app, "test.example.com"
    @rake.role :app, "yarr.example.com", :no_release => true
    expected = {
      "test.example.com" => {},
      "yarr.example.com" => {:no_release => true}
    }
    assert_equal expected, @rake.roles[:app]
  end

  def test_role_multiple_roles
    @rake.role :app, "test.example.com", :primary => true
    @rake.role :db, "yarr.example.com", :no_release => true
    expected_db = { "yarr.example.com" => {:no_release => true} }
    assert_equal expected_db, @rake.roles[:db]
    expected_app = { "test.example.com" => {:primary => true} }
    assert_equal expected_app, @rake.roles[:app]
  end

  def test_remote_task
    t = @rake.remote_task(:test_task) { 5 }
    assert_equal @task_count + 1, Rake.application.tasks.size
    assert_equal({ :roles => [] }, t.options)
  end

  def test_remote_task_all_hosts_by_default
    util_set_hosts
    t = @rake.remote_task(:test_task) { 5 }
    assert_equal %w[app.example.com db.example.com], t.target_hosts
  end

  def test_remote_task_environment_override
    old_env_hosts = ENV["HOSTS"]
    ENV["HOSTS"] = 'other1.example.com,   other2.example.com'
    util_set_hosts
    t = @rake.remote_task(:test_task) { 5 }
    assert_equal %w[other1.example.com other2.example.com], t.target_hosts
  ensure
    ENV["HOSTS"] = old_env_hosts
  end

  def test_remote_task_body_set
    set(:some_variable, 5)
    @rake.host 'www.example.com', :app
    @rake.remote_task(:some_task) do $some_task_result = some_variable end

    Rake::Task['some_task'].execute nil
    assert_equal @rake.fetch(:some_variable), $some_task_result
  end

  def test_remote_task_with_options
    t = @rake.remote_task :test_task, :roles => [:app, :db] do
      fail "should not run"
    end
    assert_equal({:roles => [:app, :db]}, t.options)
  end

  def test_remote_task_before_host_declaration
    t = @rake.remote_task :test_task, :roles => :web do 5 end
    @rake.host 'www.example.com', :web
    assert_equal %w[www.example.com], t.target_hosts
  end

  def test_remote_task_role_override
    host "db1", :db
    host "db2", :db
    host "db3", :db
    host "master", :master_db

    remote_task(:migrate_the_db, :roles => [:db]) { flunk "bad!" }
    task = Rake::Task["migrate_the_db"]
    assert_equal %w[db1 db2 db3], task.target_hosts

    task.options[:roles] = :master_db
    assert_equal %w[master], task.target_hosts

    task.options[:roles] = [:master_db]
    assert_equal %w[master], task.target_hosts
  end

  def test_set
    set :win, 5
    assert_equal 5, @rake.win
  end

  def test_set_lazy_block_evaluation
    set(:lose) { raise "lose" }
    assert_raises(RuntimeError) { @rake.lose }
  end

  def test_set_with_block
    x = 1
    set(:win) { x += 2 }

    assert_equal 3, @rake.win
    assert_equal 3, @rake.win
  end

  def test_set_with_reference
    @rake.instance_eval do
      set(:var_one) { var_two }
      set(:var_two) { var_three }
      set(:var_three) { 5 }
    end

    assert_equal 5, @rake.var_one
  end

  def test_set_with_block_and_value
    e = assert_raises(ArgumentError) do
      set(:loser, 5) { 6 }
    end
    assert_equal "cannot provide both a value and a block", e.message
  end

  def test_set_with_nil
    set(:win, nil)
    assert_equal nil, @rake.win
  end

  def test_set_with_reserved_name
    $TESTING = false
    e = assert_raises(ArgumentError) { set(:all_hosts, []) }
    assert_equal "cannot set reserved name: 'all_hosts'", e.message
  ensure
    $TESTING = true
  end
end

