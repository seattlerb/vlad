require 'singleton'
require 'vlad_tasks'

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

class Rake::RemoteTask < Rake::Task
  attr_accessor :options, :target_hosts

  def initialize(task_name, app)
    super
    @remote_actions = []
  end

  alias_method :original_enhance, :enhance
  def enhance(deps=nil, &block)
    original_enhance(deps)
    @remote_actions << block if block_given?
    self
  end

  # -- HERE BE DRAGONS --
  # We are defining singleton methods on the task AS it executes
  # for each 'set' variable. We do this because we need to be support
  # 'application' and similar Rake-reserved names inside remote tasks.
  # This relies on the current (rake 0.7.3) calling conventions.
  # If this breaks blame Jim Weirich and/or society.
  def execute
    super
    Vlad.instance.env.keys.each do |name|
      self.instance_eval "def #{name}; Vlad.instance.fetch('#{name}'); end"
    end
    @remote_actions.each { |act| self.instance_eval(&act) }
  end

  def run command
    raise Vlad::ConfigurationError, "No roles have been defined" if Vlad.instance.roles.empty?

    @target_hosts.each do |host|
      cmd = "ssh #{host} #{command}"
      retval = system cmd
      raise Vlad::CommandFailedError, "execution failed: #{cmd}" unless retval
    end
  end
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
      v = @env[name]
      v = @env[name] = v.call if Proc === v
      v
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

  def self.load path_or_string
    src = if File.exist? path_or_string then
            File.read(path_or_string)
          else
            path_or_string
          end

    self.instance.instance_eval src
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

  def reset
    @roles = Hash.new { |h,k| h[k] = {} }
    @env = {}
    @tasks = {}
    set(:application)       { raise Vlad::ConfigurationError, "Please specify the name of the application" }
    set(:repository)        { raise Vlad::ConfigurationError, "Please specify the repository type" }
  end

  def role role_name, host, args = {}
    @roles[role_name][host] = args
  end

  def set name, val = nil, &b
    raise ArgumentError, "cannot set reserved name: '#{name}'" if self.respond_to?(name)
    raise ArgumentError, "cannot provide both a value and a block" if b and val
    @env[name.to_s] = val || b
  end

  def remote_task name, options = {}, &b
    roles = options[:roles]
    t = Rake::RemoteTask.define_task(name, &b)
    t.options = options
    t.target_hosts = roles ? hosts_for(*roles) : all_hosts
    t
  end
end
