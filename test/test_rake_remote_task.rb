require 'test/vlad_test_case'
require 'vlad'

class TestRakeRemoteTask < VladTestCase
  def test_enhance
    util_set_hosts
    body = Proc.new { 5 }
    task = @vlad.remote_task(:some_task => :foo, &body)
    action = Rake::RemoteTask::Action.new(task, body)
    assert_equal [action], task.remote_actions
    assert_equal task, action.task
    assert_equal ["foo"], task.prerequisites
  end

  def test_enhance_with_no_task_body
    util_set_hosts
    util_setup_task
    assert_equal [], @task.remote_actions
    assert_equal [], @task.prerequisites
  end

  def test_execute
    util_set_hosts
    set :some_variable, 1
    x = 5
    task = @vlad.remote_task(:some_task) { x += some_variable }
    task.execute
    assert_equal 1, task.some_variable
    assert_equal 2, task.remote_actions.first.workers.size
    assert_equal 7, x
  end

  def test_execute_with_no_hosts
    @vlad.host "app.example.com", :app
    t = @vlad.remote_task(:flunk, :roles => :db) { flunk "should not have run" }
    e = assert_raise(Vlad::ConfigurationError) { t.execute }
    assert_equal "No target hosts specified for task: flunk", e.message
  end

  def test_execute_with_no_roles
    t = @vlad.remote_task(:flunk, :roles => :db) { flunk "should not have run" }
    e = assert_raise(Vlad::ConfigurationError) { t.execute }
    assert_equal "No target hosts specified for task: flunk", e.message
  end

  def test_execute_with_roles
    util_set_hosts
    set :some_variable, 1
    x = 5
    task = @vlad.remote_task(:some_task, :roles => :db) { x += some_variable }
    task.execute
    assert_equal 1, task.some_variable
    assert_equal 6, x
  end

  def test_run
    util_setup_task
    @task.target_host = "app.example.com"
    @task.run("ls")

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ["ssh", "app.example.com", "sh -c \"ls\" 2>&1"],
                 commands.first, 'app'
  end

  def test_run_failing_command
    util_set_hosts
    util_setup_task
    @task.target_host =  'app.example.com'
    @task.action = lambda { 1 }

    e = assert_raise(Vlad::CommandFailedError) { @task.run("ls") }
    assert_equal "execution failed with status 1: ssh app.example.com sh -c \"ls\" 2>&1", e.message

    assert_equal 1, @task.commands.size
  end

  def test_run_sudo
    util_setup_task
    @task.outputs << 'Password:'
    @task.target_host = "app.example.com"
    def @task.sudo_password() "my password" end # gets defined by set

    @task.run("sudo ls")

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ['ssh', 'app.example.com', 'sh -c "sudo ls" 2>&1'],
                 commands.first

    assert_equal "my password\n", @task.input.string
  end

  def util_setup_task(options = {})
    @task = @vlad.remote_task :test_task, options
    @task.commands = []
    @task.outputs = []
    @task.action = nil
    @task
  end
end
