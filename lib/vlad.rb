require 'singleton'
require 'vlad_tasks'

class Vlad
  VERSION = '1.0.0'
  class Error < RuntimeError; end
  class ConfigurationError < Error; end
  class CommandFailedError < Error; end

  include Singleton

  attr_reader :roles
  attr_accessor :target_hosts

  def initialize
    self.reset

    instance_eval File.read("config/deploy.rb") if test ?f, 'config/deploy.rb'
  end

  def role role_name, host, args = {}
    @roles[role_name][host] = args
  end

  def host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  def set name, val = nil, &b
    raise ArgumentError, "cannot set reserved name: '#{name}'" if self.respond_to?(name)
    raise ArgumentError, "cannot provide both a value and a block" if b and val
    @env[name.to_s] = val || b
  end

  def method_missing name, *other
    name = name.to_s if Symbol === name
    if @env.has_key? name and other.empty? then
      v = @env[name]
      v = @env[name] = v.call if Proc === v
      v
    else
      super
    end
  end

  def reset
    @roles = Hash.new { |h,k| h[k] = {} }
    @target_hosts = nil
    @env = {}
    set(:application)       { abort "Please specify the name of the application" }
    set(:repository)        { abort "Please specify the repository type" }
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

  def hosts_for_role(role)
    @roles[role].keys.sort
  end

  def all_hosts
    @roles.keys.map do |role|
      hosts_for_role(role)
    end.flatten.uniq.sort
  end
end
