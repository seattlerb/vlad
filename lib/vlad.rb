require 'singleton'
require 'vlad_tasks'

class Vlad
  VERSION = '1.0.0'
  class Error < RuntimeError; end
  class ConfigurationError < Error; end
  class CommandFailedError < Error; end

  include Singleton

  attr_reader :roles, :tasks
  attr_accessor :target_hosts

  def all_hosts
    @roles.keys.map do |role|
      hosts_for_role(role)
    end.flatten.uniq.sort
  end

  def desc description
    @last_description = description
  end

  def fetch(name, default = nil)
    name = name.to_s if Symbol === name
    if @env.has_key? name then
      v = @env[name]
      v = @env[name] = v.call if Proc === v
      v
    else
      raise Vlad::ConfigurationError
    end
  end

  def host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  def hosts_for_role(role)
    @roles[role].keys.sort
  end

  def initialize
    self.reset

    instance_eval File.read("config/deploy.rb") if test ?f, 'config/deploy.rb'
  end

  def method_missing name, *args
    begin
      fetch(name)
    rescue Vlad::ConfigurationError
      super
    end
  end

  def reset
    @roles = Hash.new { |h,k| h[k] = {} }
    @target_hosts = nil
    @env = {}
    @tasks = {}
    @last_description = nil
    set(:application)       { abort "Please specify the name of the application" }
    set(:repository)        { abort "Please specify the repository type" }
  end

  def role role_name, host, args = {}
    @roles[role_name][host] = args
  end

  def run command
    raise Vlad::ConfigurationError, "No roles have been defined" if @roles.empty?
    raise Vlad::ConfigurationError, "No target hosts specified" unless @target_hosts

    @target_hosts.each do |host|
      cmd = "ssh #{host} #{command}"
      retval = system cmd
      raise CommandFailedError, "execution failed: #{cmd}" unless retval
    end
  end

  def set name, val = nil, &b
    raise ArgumentError, "cannot set reserved name: '#{name}'" if self.respond_to?(name)
    raise ArgumentError, "cannot provide both a value and a block" if b and val
    @env[name.to_s] = val || b
  end

  def task name, options = {}, &b
    val = {:task => b, :options => options, :description => @last_description}
    @last_description = nil
    @tasks[name.to_s] = val
  end
end
