require 'rubygems'
require 'open4'
require 'rake'
require 'vlad'

$TESTING ||= false
$TRACE = Rake.application.options.trace

module Rake
  module TaskManager
    ##
    # This gives us access to the tasks already defined in rake.
    def all_tasks
      @tasks
    end
  end

  ##
  # Hooks into rake and allows us to clear out a task by name or
  # regexp. Use this if you want to completely override a task instead
  # of extend it.
  def self.clear_tasks(*tasks)
    tasks.flatten.each do |name|
      case name
      when Regexp then
        Rake.application.all_tasks.delete_if { |k,_| k =~ name }
      else
        Rake.application.all_tasks.delete(name)
      end
    end
  end
end

##
# Declare a remote host and its roles. Equivalent to <tt>role</tt>,
# but shorter for multiple roles.
def host host_name, *roles
  Rake::RemoteTask.host host_name, *roles
end

##
# Copy a (usually generated) file to +remote_path+. Contents of block
# are copied to +remote_path+ and you may specify an optional
# base_name for the tempfile (aids in debugging).

def put remote_path, base_name = 'vlad.unknown'
  Tempfile.open base_name do |fp|
    fp.puts yield
    fp.flush
    rsync fp.path, remote_path
  end
end

##
# Declare a Vlad task that will execute on all hosts by default. To
# limit that task to specific roles, use:
#
#     remote_task :example, :roles => [:app, :web] do
def remote_task name, options = {}, &b
  Rake::RemoteTask.remote_task name, options, &b
end

##
# Declare a role and assign a remote host to it. Equivalent to the
# <tt>host</tt> method; provided for capistrano compatibility.
def role role_name, host = nil, args = {}
  if block_given? then
    raise ArgumentError, 'host not allowed with block' unless host.nil?

    begin
      Rake::RemoteTask.current_roles << role_name
      yield
    ensure
      Rake::RemoteTask.current_roles.delete role_name
    end
  else
    raise ArgumentError, 'host required' if host.nil?
    Rake::RemoteTask.role role_name, host, args
  end
end

##
# Execute the given command on the <tt>target_host</tt> for the
# current task.
def run *args, &b
  Thread.current[:task].run(*args, &b)
end

# rsync the given files to <tt>target_host</tt>.
def rsync local, remote
  Thread.current[:task].rsync local, remote
end

# Declare a variable called +name+ and assign it a value. A
# globally-visible method with the name of the variable is defined.
# If a block is given, it will be called when the variable is first
# accessed. Subsequent references to the variable will always return
# the same value. Raises <tt>ArgumentError</tt> if the +name+ would
# conflict with an existing method.
def set name, val = nil, &b
  Rake::RemoteTask.set name, val, &b
end

# Returns the name of the host that the current task is executing on.
# <tt>target_host</tt> can uniquely identify a particular task/host
# combination.
def target_host
  Thread.current[:task].target_host
end

if Gem::Version.new(RAKEVERSION) < Gem::Version.new('0.8') then
  class Rake::Task
    alias vlad_original_execute execute

    def execute(args = nil)
      vlad_original_execute
    end
  end
end

##
# Rake::RemoteTask is a subclass of Rake::Task that adds
# remote_actions that execute in parallel on multiple hosts via ssh.

class Rake::RemoteTask < Rake::Task

  @@current_roles = []

  include Open4

  ##
  # Options for execution of this task.

  attr_accessor :options

  ##
  # The host this task is running on during execution.

  attr_accessor :target_host

  ##
  # An Array of Actions this host will perform during execution. Use
  # enhance to add new actions to a task.

  attr_reader :remote_actions

  def self.current_roles
    @@current_roles
  end

  ##
  # Create a new task named +task_name+ attached to Rake::Application +app+.

  def initialize(task_name, app)
    super
    @remote_actions = []
  end

  ##
  # Add a local action to this task. This calls Rake::Task#enhance.

  alias_method :original_enhance, :enhance

  ##
  # Add remote action +block+ to this task with dependencies +deps+. See
  # Rake::Task#enhance.

  def enhance(deps=nil, &block)
    original_enhance(deps) # can't use super because block passed regardless.
    @remote_actions << Action.new(self, block) if block_given?
    self
  end

  ##
  # Execute this action. Local actions will be performed first, then remote
  # actions will be performed in parallel on each host configured for this
  # RemoteTask.

  def execute(args = nil)
    raise(Vlad::ConfigurationError,
          "No target hosts specified on task #{self.name} for roles #{options[:roles].inspect}") if
      target_hosts.empty?

    super args

    @remote_actions.each { |act| act.execute(target_hosts, args) }
  end

  ##
  # Use rsync to send +local+ to +remote+ on target_host.

  def rsync local, remote
    cmd = [rsync_cmd, rsync_flags, local, "#{@target_host}:#{remote}"]
    cmd = cmd.flatten.compact

    warn cmd.join(' ') if $TRACE

    success = system(*cmd)

    unless success then
      raise Vlad::CommandFailedError, "execution failed: #{cmd.join ' '}"
    end
  end

  ##
  # Use ssh to execute +command+ on target_host. If +command+ uses sudo, the
  # sudo password will be prompted for then saved for subsequent sudo commands.

  def run command
    cmd = [ssh_cmd, ssh_flags, target_host, command].flatten
    result = []

    warn cmd.join(' ') if $TRACE

    pid, inn, out, err = popen4(*cmd)

    inn.sync   = true
    streams    = [out, err]
    out_stream = {
      out => $stdout,
      err => $stderr,
    }

    # Handle process termination ourselves
    status = nil
    Thread.start do
      status = Process.waitpid2(pid).last
    end

    until streams.empty? do
      # don't busy loop
      selected, = select streams, nil, nil, 0.1

      next if selected.nil? or selected.empty?

      selected.each do |stream|
        if stream.eof? then
          streams.delete stream if status # we've quit, so no more writing
          next
        end

        data = stream.readpartial(1024)
        out_stream[stream].write data

        if stream == err and data =~ /^Password:/ then
          inn.puts sudo_password
          data << "\n"
          $stderr.write "\n"
        end

        result << data
      end
    end

    unless status.success? then
      raise(Vlad::CommandFailedError,
            "execution failed with status #{status.exitstatus}: #{cmd.join ' '}")
    end

    result.join
  end

  ##
  # Returns an Array with every host configured.

  def self.all_hosts
    hosts_for(roles.keys)
  end

  ##
  # The default environment values. Used for resetting (mostly for
  # tests).

  def self.default_env
    @@default_env
  end

  ##
  # The vlad environment.

  def self.env
    @@env
  end

  ##
  # Fetches environment variable +name+ from the environment using
  # default +default+.

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
  # Add host +host_name+ that belongs to +roles+. Extra arguments may
  # be specified for the host as a hash as the last argument.
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

  def self.mandatory name, desc # :nodoc:
    self.set(name) do
      raise(Vlad::ConfigurationError,
            "Please specify the #{desc} via the #{name.inspect} variable")
    end
  end

  ##
  # Ensures exclusive access to +name+.

  def self.protect_env name # :nodoc:
    @@env_locks[name].synchronize do
      yield
    end
  end

  ##
  # Adds a remote task named +name+ with options +options+ that will
  # execute +block+.

  def self.remote_task name, options = {}, &block
    t = Rake::RemoteTask.define_task(name, &block)
    options[:roles] = Array options[:roles]
    options[:roles] |= @@current_roles
    t.options = options
    t
  end

  ##
  # Ensures +name+ does not conflict with an existing method.

  def self.reserved_name? name # :nodoc:
    !@@env.has_key?(name.to_s) && self.respond_to?(name)
  end

  ##
  # Resets vlad, restoring all roles, tasks and environment variables
  # to the defaults.

  def self.reset
    @@roles = Hash.new { |h,k| h[k] = {} }
    @@env = {}
    @@tasks = {}
    @@env_locks = Hash.new { |h,k| h[k] = Mutex.new }

    @@default_env.each do |k,v|
      case v
      when Symbol, Fixnum, nil, true, false, 42 then # ummmm... yeah. bite me.
        @@env[k] = v
      else
        @@env[k] = v.dup
      end
    end
  end

  ##
  # Adds role +role_name+ with +host+ and +args+ for that host.

  def self.role role_name, host, args = {}
    raise ArgumentError, "invalid host" if host.nil? or host.empty?
    @@roles[role_name][host] = args
  end

  ##
  # The configured roles.

  def self.roles
    host domain, :app, :web, :db if @@roles.empty?

    @@roles
  end

  ##
  # Set environment variable +name+ to +value+ or +default_block+.
  #
  # If +default_block+ is defined, the block will be executed the
  # first time the variable is fetched, and the value will be used for
  # every subsequent fetch.

  def self.set name, value = nil, &default_block
    raise ArgumentError, "cannot provide both a value and a block" if
      value and default_block
    raise ArgumentError, "cannot set reserved name: '#{name}'" if
      Rake::RemoteTask.reserved_name?(name) unless $TESTING

    Rake::RemoteTask.default_env[name.to_s] = Rake::RemoteTask.env[name.to_s] =
      value || default_block

    Object.send :define_method, name do
      Rake::RemoteTask.fetch name
    end
  end

  ##
  # Sets all the default values. Should only be called once. Use reset
  # if you need to restore values.

  def self.set_defaults
    @@default_env ||= {}
    self.reset

    mandatory :repository, "repository path"
    mandatory :deploy_to,  "deploy path"
    mandatory :domain,     "server domain"

    simple_set(:deploy_timestamped, true,
               :deploy_via,         :export,
               :keep_releases,      5,
               :migrate_args,       "",
               :migrate_target,     :latest,
               :rails_env,          "production",
               :rake_cmd,           "rake",
               :revision,           "head",
               :rsync_cmd,          "rsync",
               :rsync_flags,        ['-azP', '--delete'],
               :ssh_cmd,            "ssh",
               :ssh_flags,          [],
               :sudo_cmd,           "sudo",
               :sudo_flags,         nil,
               :umask,              '02')

    set(:current_release)    { File.join(releases_path, releases[-1]) }
    set(:latest_release)     { deploy_timestamped ?release_path: current_release }
    set(:previous_release)   { File.join(releases_path, releases[-2]) }
    set(:release_name)       { Time.now.utc.strftime("%Y%m%d%H%M%S") }
    set(:release_path)       { File.join(releases_path, release_name) }
    set(:releases)           { task.run("ls -x #{releases_path}").split.sort }

    set_path :current_path,  "current"
    set_path :releases_path, "releases"
    set_path :scm_path,      "scm"
    set_path :shared_path,   "shared"

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

  def self.set_path(name, subdir) # :nodoc:
    set(name) { File.join(deploy_to, subdir) }
  end

  def self.simple_set(*args) # :nodoc:
    args = Hash[*args]
    args.each do |k, v|
      set k, v
    end
  end

  ##
  # The Rake::RemoteTask executing in this Thread.

  def self.task
    Thread.current[:task]
  end

  ##
  # The configured Rake::RemoteTasks.

  def self.tasks
    @@tasks
  end

  ##
  # Execute +command+ under sudo using run.

  def sudo command
    run [sudo_cmd, sudo_flags, command].compact.join(" ")
  end

  ##
  # The hosts this task will execute on. The hosts are determined from
  # the role this task belongs to.
  #
  # The target hosts may be overridden by providing a comma-separated
  # list of commands to the HOSTS environment variable:
  #
  #   rake my_task HOSTS=app1.example.com,app2.example.com

  def target_hosts
    if hosts = ENV["HOSTS"] then
      hosts.strip.gsub(/\s+/, '').split(",")
    else
      roles = Array options[:roles]

      if roles.empty? then
        Rake::RemoteTask.all_hosts
      else
        Rake::RemoteTask.hosts_for roles
      end
    end
  end

  ##
  # Action is used to run a task's remote_actions in parallel on each
  # of its hosts. Actions are created automatically in
  # Rake::RemoteTask#enhance.

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
    # Execute this action on +hosts+ in parallel. Returns when block
    # has completed for each host.

    def execute hosts, args = nil
      hosts.each do |host|
        t = task.clone
        t.target_host = host
        thread = Thread.new(t) do |task|
          Thread.current[:task] = task
          block.call args
        end
        @workers << thread
      end
      @workers.each { |w| w.join }
    end
  end
end

Rake::RemoteTask.set_defaults
