require 'test/vlad_test_case'
require 'vlad'

class TestRakeRemoteTask < VladTestCase
  def test_run
    util_set_hosts
    util_setup_task
    @task.run("ls")

    commands = @task.commands

    assert_equal 2, commands.size, 'not enough commands'
    assert commands.include?("ssh app.example.com ls"), 'app'
    assert commands.include?("ssh db.example.com ls"), 'db'
  end

  def test_run_failing_command
    util_set_hosts
    util_setup_task
    @task.action = lambda { false }
    assert_raise(Vlad::CommandFailedError) { @task.run("ls") }
    assert_equal 1, @task.commands.size
  end

  def test_run_with_no_hosts
    @vlad.host "app.example.com", :app
    @task = @vlad.task :test_task, :roles => :db
    @task.commands = []
    @task.action = nil

    @task.run "ls"
    assert_equal [], @task.commands
  end

  def test_run_with_no_roles
    @task = @vlad.task :test_task
    e = assert_raise(Vlad::ConfigurationError) { @task.run "ls" }
    assert_equal "No roles have been defined", e.message
  end

  def util_setup_task
    @task = @vlad.task :test_task
    @task.commands = []
    @task.action = nil
    @task
  end
end
