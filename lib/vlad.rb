require 'rubygems'
require 'rake'
require 'thread'
require 'rake_remote_task'

def host host_name, *roles
  Rake::RemoteTask.host host_name, *roles
end

def remote_task name, options = {}, &b
  Rake::RemoteTask.remote_task name, options, &b
end

def role role_name, host, args = {}
  Rake::RemoteTask.role role_name, host, args
end

def run *args, &b
  Thread.current[:task].run(*args, &b)
end

def set name, val = nil, &b
  raise ArgumentError, "cannot provide both a value and a block" if val and b
  raise ArgumentError, "cannot set reserved name: '#{name}'" if Rake::RemoteTask.reserved_name?(name)
  Rake::RemoteTask.env[name.to_s] = val || b

  Object.send :define_method, name do
    Rake::RemoteTask.fetch name
  end
end

def target_host
  Thread.current[:task].target_host
end

module Vlad
  VERSION = '1.0.0'

  class Error < RuntimeError; end
  class ConfigurationError < Error; end
  class CommandFailedError < Error; end
  class FetchError < Error; end

end

Rake::RemoteTask.reset

