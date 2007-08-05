require 'singleton'

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

    # set(:application)       { abort "Please specify the name of your application, set :application, 'foo'" }
    # set(:repository)        { abort "Please specify the repository that houses your application's code, set :repository, 'foo'" }
    # set :scm,               :subversion
    # set :deploy_via,        :checkout
    # set(:deploy_to)         { "/u/apps/#{application}" }
    # set(:revision)          { source.head }
    # set(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
    # set(:real_revision)     { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { `#{cmd}` } } }
    # set(:strategy)          { Capistrano::Deploy::Strategy.new(deploy_via, self) }
    # set(:release_name)      { set :deploy_timestamped, true; Time.now.utc.strftime("%Y%m%d%H%M%S") }
    # set(:releases_path)     { File.join(deploy_to, "releases") }
    # set(:shared_path)       { File.join(deploy_to, "shared") }
    # set(:current_path)      { File.join(deploy_to, "current") }
    # set(:release_path)      { File.join(releases_path, release_name) }
    # set(:releases)          { capture("ls -x #{releases_path}").split.sort }
    # set(:current_release)   { File.join(releases_path, releases.last) }
    # set(:previous_release)  { File.join(releases_path, releases[-2]) }
    # set(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
    # set(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
    # set(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp }
    # set(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }
    # set(:latest_release)    { exists?(:deploy_timestamped) ? release_path : current_release }

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
    @env[name] = val || b
  end

  def method_missing name, *other
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
    @roles[role].keys
  end
  
  def all_hosts
    @roles.keys.map do |role| 
      hosts_for_role(role)
    end.flatten.uniq.sort
  end
end

require 'rubygems'
require 'rake'

task :debug_vlad do
  y Vlad.instance
end
