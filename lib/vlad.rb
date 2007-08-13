require 'rubygems'
require 'rake'
require 'thread'
require 'rake_remote_task'

# Declare a remote host and its roles. 
# Equivalent to <tt>role</tt>, but shorter for multiple roles. 
def host host_name, *roles
  Rake::RemoteTask.host host_name, *roles
end

# Declare a Vlad task that will execute on all hosts by default.
# To limit that task to specific roles, use:
# remote_task :example, :roles => [:app, :web] do
def remote_task name, options = {}, &b
  Rake::RemoteTask.remote_task name, options, &b
end

# Declare a role and assign a remote host to it.
# Equivalent to the <tt>host</tt> method; provided for capistrano compatibility.
def role role_name, host, args = {}
  Rake::RemoteTask.role role_name, host, args
end

# Execute the given command on the <tt>target_host</tt> for the current task.
def run *args, &b
  Thread.current[:task].run(*args, &b)
end

# rsync the given files to <tt>target_host</tt>.
def rsync local, remote
  Thread.current[:task].rsync local, remote
end

# Declare a variable called +name+ and assign it a value.
# A globally-visible method with the name of the variable is defined.
# If a block is given, it will be called when the variable is first accessed.
# Subsequent references to the variable will always return the same value.
# Raises <tt>ArgumentError</tt> if the +name+ would conflict with an existing method.
def set name, val = nil, &b
  Rake::RemoteTask.set name, val, &b
end

# Returns the name of the host that the current task is executing on.
# <tt>target_host</tt> can uniquely identify a particular task/host combination.
def target_host
  Thread.current[:task].target_host
end

module Vlad

  # This is the version of Vlad you are running.
  VERSION = '1.0.0'

  # Base error class for all Vlad errors.
  class Error < RuntimeError; end

  # Raised when you have incorrectly configured Vlad.
  class ConfigurationError < Error; end

  # Raised when a remote command fails.
  class CommandFailedError < Error; end

  # Raised when an environment variable hasn't been set.
  class FetchError < Error; end

  # Loads tasks file +tasks_file+ and the vlad_tasks file.
  def self.load tasks_file = 'config/deploy.rb'
    Kernel.load tasks_file
    require 'vlad_tasks'
  end

end

Rake::RemoteTask.reset

