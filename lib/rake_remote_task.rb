require 'rubygems'
require 'open4'
require 'rake'
require 'vlad'

$TESTING ||= false

module Rake
  module TaskManager
    ##
    # This gives us access to the tasks already defined in rake.
    attr_reader :tasks
  end

  def self.clear_tasks(*tasks)
    tasks.flatten.each do |name|
      case name
      when Regexp then
        Rake.application.tasks.delete_if { |k,v| k =~ name }
      else
        Rake.application.tasks.delete(name)
      end
    end
  end
end

##
# Declare a remote host and its roles.
# Equivalent to <tt>role</tt>, but shorter for multiple roles.
def host host_name, *roles
  Rake::RemoteTask.host host_name, *roles
end

##
# Declare a Vlad task that will execute on all hosts by default.
# To limit that task to specific roles, use:
# remote_task :example, :roles => [:app, :web] do
def remote_task name, options = {}, &b
  Rake::RemoteTask.remote_task name, options, &b
end

##
# Declare a role and assign a remote host to it.
# Equivalent to the <tt>host</tt> method; provided for capistrano compatibility.
def role role_name, host, args = {}
  Rake::RemoteTask.role role_name, host, args
end

##
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

##
# Rake::RemoteTask is a subclass of Rake::Task that adds remote_actions that
# execute in parallel on multiple hosts via ssh.

class Rake::RemoteTask < Rake::Task

  include Open4

  ##
  # Options for execution of this task.

  attr_accessor :options

  ##
  # The host this task is running on during execution.

  attr_accessor :target_host

  ##
  # An Array of Actions this host will perform during execution.  Use enhance
  # to add new actions to a task.

  attr_reader :remote_actions

  ##
  # Create a new task named +task_name+ attached to Rake::Application +app+.

  def initialize(task_name, app)
    super
    @remote_actions = []
  end

  ##
  # Add a local action to this task.  This calls Rake::Task#enhance.

  alias_method :original_enhance, :enhance

  ##
  # Add remote action +block+ to this task with dependencies +deps+.  See
  # Rake::Task#enhance.

  def enhance(deps=nil, &block)
    original_enhance(deps) # can't use super because block passed regardless.
    @remote_actions << Action.new(self, block) if block_given?
    self
  end

  ##
  # Execute this action.  Local actions will be performed first, then remote
  # actions will be performed in parallel on each host configured for this
  # RemoteTask.

  def execute
    raise Vlad::ConfigurationError, "No target hosts specified for task: #{self.name}" if target_hosts.empty?
    super
    @remote_actions.each { |act| act.execute(target_hosts) }
  end

  ##
  # Use rsync to send +local+ to +remote+ on target_host.

  def rsync local, remote
    cmd = ['rsync', '-azP', '--delete', local, "#{@target_host}:#{remote}"]

    success = system(*cmd)

    unless success then
      raise Vlad::CommandFailedError, "execution failed: #{cmd.join ' '}"
    end
  end

  ##
  # Use ssh to execute +command+ on target_host.  If +command+ uses sudo, the
  # sudo password will be prompted for then saved for subsequent sudo commands.

  def run command
    cmd = ["ssh", target_host, command]
    result = []

    puts cmd.join(' ') if Rake.application.options.trace

    status = popen4(*cmd) do |pid, inn, out, err|
      inn.sync = true

      until out.eof? and err.eof? do
        unless err.eof? then
          data = err.readpartial(1024)
          result << data
          $stderr.write data

          if data =~ /^Password:/ then
            inn.puts sudo_password
            result << "\n"
            $stderr.write "\n"
          end
        end

        unless out.eof? then
          data = out.readpartial(1024)
          result << data
          $stdout.write data
        end
      end
    end

    unless status.success? then
      raise Vlad::CommandFailedError, "execution failed with status #{status.exitstatus}: #{cmd.join ' '}"
    end

    result.join
  end

  ##
  # Execute +command+ under sudo using run.

  def sudo command
    run "sudo #{command}"
  end

  ##
  # The hosts this task will execute on.  The hosts are determined from the
  # role this task belongs to.
  #
  # The target hosts may be overridden by providing a comma-separated list of
  # commands to the HOSTS environment variable:
  #
  #   rake my_task HOSTS=app1.example.com,app2.example.com

  def target_hosts
    if hosts = ENV["HOSTS"] then
      hosts.strip.gsub(/\s+/, '').split(",")
    else
      roles = options[:roles]
      roles ? Rake::RemoteTask.hosts_for(roles) : Rake::RemoteTask.all_hosts
    end
  end

  ##
  # Returns an Array with every host configured.

  def self.all_hosts
    hosts_for(roles.keys)
  end

  ##
  # Fetches environment variable +name+ from the environment using default
  # +default+.

  def self.fetch name, default = nil
    name = name.to_s if Symbol === name
    if @@env.has_key? name then
      protect_env(name) do
        v = @@env[name]
        v = @@env[name] = v.call if Proc === v
        v
      end
    elsif default
      v = @@env[name] = default
    else
      raise Vlad::FetchError
    end
  end

  ##
  # Add host +host_name+ that belongs to +roles+.  Extra arguments may be
  # specified for the host as a hash as the last argument.
  #
  # host is the inversion of role:
  #
  #   host 'db1.example.com', :db, :master_db
  #
  # Is equivalent to:
  #
  #   role :db, 'db1.example.com'
  #   role :master_db, 'db1.example.com'

  def self.host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  ##
  # Returns an Array of all hosts in +roles+.

  def self.hosts_for *roles
    roles.flatten.map { |r|
      self.roles[r].keys
    }.flatten.uniq.sort
  end

  ##
  # Ensures exclusive access to +name+.

  def self.protect_env name # :nodoc:
    @@env_locks[name.to_s].synchronize do
      yield
    end
  end

  ##
  # Ensures +name+ does not conflict with an existing method.

  def self.reserved_name? name # :nodoc:
    !@@env.has_key?(name.to_s) && self.respond_to?(name)
  end

  ##
  # The Rake::RemoteTask executing in this Thread.

  def self.task
    Thread.current[:task]
  end

  ##
  # The configured roles.

  def self.roles
    host domain, :app, :web, :db if @@roles.empty?

    @@roles
  end

  ##
  # The configured Rake::RemoteTasks.

  def self.tasks
    @@tasks
  end

  ##
  # The vlad environment.

  def self.env
    @@env
  end

  ##
  # Resets vlad, restoring all roles, tasks and environment variables to the
  # defaults.

  def self.reset
    @@roles = Hash.new { |h,k| h[k] = {} }
    @@env = {}
    @@tasks = {}
    @@env_locks = Hash.new { |h,k| h[k] = Mutex.new }

    # mandatory
    set(:repository)  { raise(Vlad::ConfigurationError,
                              "Please specify the repository path") }
    set(:deploy_to)   { raise(Vlad::ConfigurationError,
                              "Please specify the deploy path") }
    set(:domain)      { raise(Vlad::ConfigurationError,
                              "Please specify the server domain") }

    # optional
    set(:current_path)    { File.join(deploy_to, "current") }
    set(:current_release) { File.join(releases_path, releases[-1]) }
    set :keep_releases, 5
    set :deploy_timestamped, true
    set :deploy_via, :export
    set(:latest_release)  { deploy_timestamped ? release_path : current_release }
    set :migrate_args, ""
    set :migrate_target, :latest
    set(:previous_release){ File.join(releases_path, releases[-2]) }
    set :rails_env, "production"
    set :rake, "rake"
    set(:release_name)    { Time.now.utc.strftime("%Y%m%d%H%M%S") }
    set(:release_path)    { File.join(releases_path, release_name) }
    set(:releases)        { task.run("ls -x #{releases_path}").split.sort }
    set(:releases_path)   { File.join(deploy_to, "releases") }
    set :scm, :subversion
    set(:scm_path)        { File.join(deploy_to, "scm") }
    set(:shared_path)     { File.join(deploy_to, "shared") }

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

    set(:source) do
      require "vlad/#{scm}"
      Vlad.const_get(scm.to_s.capitalize).new
    end
  end

  ##
  # Adds role +role_name+ with +host+ and +args+ for that host.

  def self.role role_name, host, args = {}
    raise ArgumentError, "invalid host" if host.nil? or host.empty?
    @@roles[role_name][host] = args
  end

  ##
  # Adds a remote task named +name+ with options +options+ that will execute
  # +block+.

  def self.remote_task name, options = {}, &block
    t = Rake::RemoteTask.define_task(name, &block)
    t.options = options
    roles = options[:roles]
    t
  end

  ##
  # Set environment variable +name+ to +value+ or +default_block+.
  #
  # If +default_block+ is defined, the block will be executed the first time
  # the variable is fetched, and the value will be used for every subsequent
  # fetch.

  def self.set name, value = nil, &default_block
    raise ArgumentError, "cannot provide both a value and a block" if
      value and default_block
    raise ArgumentError, "cannot set reserved name: '#{name}'" if
      Rake::RemoteTask.reserved_name?(name) unless $TESTING

    Rake::RemoteTask.env[name.to_s] = value || default_block

    Object.send :define_method, name do
      Rake::RemoteTask.fetch name
    end
  end

  ##
  # Action is used to run a task's remote_actions in parallel on each of its
  # hosts.  Actions are created automatically in Rake::RemoteTask#enhance.

  class Action

    ##
    # The task this action is attached to.

    attr_reader :task

    ##
    # The block this action will execute.

    attr_reader :block

    ##
    # An Array of threads, one for each host this action executes on.

    attr_reader :workers

    ##
    # Creates a new Action that will run +block+ for +task+.

    def initialize task, block
      @task  = task
      @block = block
      @workers = []
    end

    def == other # :nodoc:
      return false unless Action === other
      block == other.block && task == other.task
    end

    ##
    # Execute this action on +hosts+ in parallel.  Returns when block has
    # completed for each host.

    def execute hosts
      hosts.each do |host|
        t = task.clone
        t.target_host = host
        thread = Thread.new(t) do |task|
          Thread.current[:task] = task
          block.call
        end
        @workers << thread
      end
      @workers.each { |w| w.join }
    end
  end
end

Rake::RemoteTask.reset
