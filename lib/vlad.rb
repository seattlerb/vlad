require 'rubygems'
require 'rake'
require 'singleton'
require 'thread'
require 'rake_remote_task'

def remote_task name, options = {}, &b
  Vlad.instance.remote_task name, options, &b
end

def set name, val = nil, &b
  Vlad.instance.set name, val, &b
end

def role role_name, host, args = {}
  Vlad.instance.role role_name, host, args
end

def host host_name, *roles
  Vlad.instance.host host_name, *roles
end

class Vlad
  VERSION = '1.0.0'

  class Error < RuntimeError; end
  class ConfigurationError < Error; end
  class CommandFailedError < Error; end
  class FetchError < Error; end

  include Singleton

  attr_reader :roles, :tasks, :env

  def all_hosts
    hosts_for(@roles.keys)
  end

  def fetch(name, default = nil)
    name = name.to_s if Symbol === name
    if @env.has_key? name then
      protect_env(name) do
        v = @env[name]
        v = @env[name] = v.call if Proc === v
        v
      end
    elsif default
      v = @env[name] = default
    else
      raise Vlad::FetchError
    end
  end

  def host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  def hosts_for(*roles)
    roles.flatten.map do |r|
      @roles[r].keys
    end.flatten.uniq.sort
  end

  def self.load path
    self.instance.instance_eval File.read(path)
    require 'vlad_tasks'
  end

  def initialize
    self.reset
  end

  def method_missing name, *args
    begin
      fetch(name)
    rescue Vlad::FetchError
      super
    end
  end

  def protect_env(name)
    @env_locks[name.to_s].synchronize do
      yield
    end
  end

  def reset
    @roles = Hash.new { |h,k| h[k] = {} }
    @env = {}
    @tasks = {}
    @env_locks = Hash.new { |h,k| h[k] = Mutex.new }
    set(:application)   { raise Vlad::ConfigurationError, "Please specify the name of the application" }
    set(:repository)    { raise Vlad::ConfigurationError, "Please specify the repository type" }
    set(:releases_path)     { File.join(deploy_to, "releases") }
    set(:shared_path)       { File.join(deploy_to, "shared") }
    set(:current_path)      { File.join(deploy_to, "current") }
    set(:release_name)      { # TODO: clean up
      set :deploy_timestamped, true
      Time.now.utc.strftime("%Y%m%d%H%M%S")
    }
    set(:release_path)      { File.join(releases_path, release_name) }

    set(:sudo_password) do
      state = `stty -g`

      raise Vlad::Error, "stty(1) not found" unless $?.success?

      begin
        system "stty -echo"
        $stdout.print "sudo password: "
        $stdout.flush
        sudo_password = $stdin.gets
        $stdout.puts
      ensure
        system "stty #{state}"
      end
      sudo_password
    end
  end

  def role role_name, host, args = {}
    raise ArgumentError, "invalid host" if host.nil? or host.empty?
    @roles[role_name][host] = args
  end

  def set name, val = nil, &b
    raise ArgumentError, "cannot set reserved name: '#{name}'" if self.respond_to?(name)
    raise ArgumentError, "cannot provide both a value and a block" if b and val
    protect_env(name.to_s) do
      @env[name.to_s] = val || b
    end
  end

  def remote_task name, options = {}, &b
    t = Rake::RemoteTask.define_task(name, &b)
    t.options = options
    roles = options[:roles]
    t
  end
end
