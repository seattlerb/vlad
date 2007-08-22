require 'test/vlad_test_case'
require 'vlad'

$TESTING = true

class TestVlad < VladTestCase
  def test_all_hosts
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.all_hosts
  end

  def test_fetch
    set :foo, 5
    assert_equal 5, @vlad.fetch(:foo)
  end

  def test_fetch_with_default
    assert_equal 5, @vlad.fetch(:not_here, 5)
  end

  def test_host
    @vlad.host "test.example.com", :app, :db
    expected = {"test.example.com" => {}}
    assert_equal expected, @vlad.roles[:app]
    assert_equal expected, @vlad.roles[:db]
  end

  def test_host_invalid
    assert_raise(ArgumentError) { @vlad.host "", :app, :db }
    assert_raise(ArgumentError) { @vlad.host nil, :web }
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

  def test_hosts_for_array_of_roles
    util_set_hosts
    assert_equal %w[app.example.com db.example.com], @vlad.hosts_for([:app, :db])
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

  def test_hosts_for_unique
    util_set_hosts
    @vlad.host "app.example.com", :web
    assert_equal %w[app.example.com db.example.com], @vlad.hosts_for(:app, :db, :web)
  end

  def test_initialize
    @vlad.reset
    assert_raise(Vlad::ConfigurationError) { @vlad.repository }
    assert_raise(Vlad::ConfigurationError) { @vlad.deploy_to }
    assert_raise(Vlad::ConfigurationError) { @vlad.domain }
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

  def test_remote_task_environment_override
    old_env_hosts = ENV["HOSTS"]
    ENV["HOSTS"] = 'other1.example.com,   other2.example.com'
    util_set_hosts
    t = @vlad.remote_task(:test_task) { 5 }
    assert_equal %w[other1.example.com other2.example.com], t.target_hosts
  ensure 
    ENV["HOSTS"] = old_env_hosts
  end

  def test_remote_task_body_set
    set(:some_variable, 5)
    @vlad.host 'www.example.com', :app
    @vlad.remote_task(:some_task) do $some_task_result = some_variable end

    Rake::Task['some_task'].execute
    assert_equal @vlad.fetch(:some_variable), $some_task_result
  end

  def test_remote_task_with_options
    t = @vlad.remote_task :test_task, :roles => [:app, :db] do
      fail "should not run"
    end
    assert_equal({:roles => [:app, :db]}, t.options)
  end

  def test_remote_task_before_host_declaration
    t = @vlad.remote_task :test_task, :roles => :web do 5 end
    @vlad.host 'www.example.com', :web
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

  def test_source
    set :scm, :perforce
    assert_equal "Vlad::Perforce", @vlad.source.class.name
  end

  def test_source_default
    assert_equal "Vlad::Subversion", @vlad.source.class.name
  end

  def test_source_singleton
    s1 = @vlad.source
    s2 = @vlad.source
    assert_equal s1.object_id, s2.object_id
  end

  def test_set
    set :test, 5
    assert_equal 5, @vlad.test
  end

  def test_set_lazy_block_evaluation
    set(:test) { fail "lose" }
    assert_raise(RuntimeError) { @vlad.test }
  end

  def test_set_with_block
    x = 1
    set(:test) { x += 2 }

    assert_equal 3, @vlad.test
    assert_equal 3, @vlad.test
  end

  def test_set_with_reference
    @vlad.instance_eval do
      set(:var_one) { var_two }
      set(:var_two) { var_three }
      set(:var_three) { 5 }
    end

    assert_equal 5, @vlad.var_one
  end

  def test_set_with_block_and_value
    e = assert_raise(ArgumentError) do
      set(:test, 5) { 6 }
    end
    assert_equal "cannot provide both a value and a block", e.message
  end

  def test_set_with_nil
    set(:test, nil)
    assert_equal nil, @vlad.test
  end

  def test_set_with_reserved_name
    $TESTING = false
    e = assert_raise(ArgumentError) { set(:all_hosts, []) }
    assert_equal "cannot set reserved name: 'all_hosts'", e.message
  ensure
    $TESTING = true
  end
end

