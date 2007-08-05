require 'singleton'

class Vlad
  VERSION = '1.0.0'

  include Singleton

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

  def role name, host, args = nil
    @roles[name] = [host, args]
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
    @roles = {}
    @env = {}
  end
end
