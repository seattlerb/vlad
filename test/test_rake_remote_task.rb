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

  def test_rsync
    util_setup_task
    @task.target_host = "app.example.com"

    @task.rsync 'localfile', 'remotefile'

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal %w[rsync -aqz --delete localfile app.example.com:remotefile],
                 commands.first, 'rsync'
  end

  def test_rsync_fail
    util_setup_task
    @task.target_host = "app.example.com"
    @task.action = lambda { false }

    e = assert_raise(Vlad::CommandFailedError) { @task.rsync 'local', 'remote' }
    assert_equal "execution failed: rsync -aqz --delete local app.example.com:remote", e.message
  end

  def test_run
    util_setup_task
    @task.output << "file1\nfile2\n"
    @task.target_host = "app.example.com"
    result = nil

    out, err = util_capture do
      result = @task.run("ls")
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ["ssh", "app.example.com", "ls"],
                 commands.first, 'app'
    assert_equal "file1\nfile2\n", result

    assert_equal "file1\nfile2\n", out.read
    assert_equal '', err.read
  end

  def test_run_failing_command
    util_set_hosts
    util_setup_task
    @task.input = StringIO.new "file1\nfile2\n"
    @task.target_host =  'app.example.com'
    @task.action = lambda { 1 }

    e = assert_raise(Vlad::CommandFailedError) { @task.run("ls") }
    assert_equal "execution failed with status 1: ssh app.example.com ls", e.message

    assert_equal 1, @task.commands.size
  end

  def test_run_sudo
    util_setup_task
    @task.output << "file1\nfile2\n"
    @task.error << 'Password:'
    @task.target_host = "app.example.com"
    def @task.sudo_password() "my password" end # gets defined by set
    result = nil

    out, err = util_capture do
      result = @task.run("sudo ls")
    end

    commands = @task.commands

    assert_equal 1, commands.size, 'not enough commands'
    assert_equal ['ssh', 'app.example.com', 'sudo ls'],
                 commands.first

    assert_equal "my password\n", @task.input.string
    assert_equal "Password:\nfile1\nfile2\n", result

    assert_equal "file1\nfile2\n", out.read
    assert_equal "Password:\n", err.read
  end

  def test_sudo
    util_setup_task
    @task.target_host = "app.example.com"
    @task.sudo "ls" 

    commands = @task.commands

    assert_equal 1, commands.size, 'wrong number of commands'
    assert_equal ["ssh", "app.example.com", "sudo ls"],
                 commands.first, 'app'
  end

  def util_capture
    require 'stringio'
    orig_stdout = $stdout.dup
    orig_stderr = $stderr.dup
    captured_stdout = StringIO.new
    captured_stderr = StringIO.new
    $stdout = captured_stdout
    $stderr = captured_stderr
    yield
    captured_stdout.rewind
    captured_stderr.rewind
    return captured_stdout, captured_stderr
  ensure
    $stdout = orig_stdout
    $stderr = orig_stderr
  end

  def util_setup_task(options = {})
    @task = @vlad.remote_task :test_task, options
    @task.commands = []
    @task.output = []
    @task.error = []
    @task.action = nil
    @task
  end
end
