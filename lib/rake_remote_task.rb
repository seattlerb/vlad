require 'rubygems'
require 'open4'
require 'vlad'

class Rake::RemoteTask < Rake::Task
  include Open4

  attr_accessor :options, :target_host
  attr_reader :remote_actions

  def initialize(task_name, app)
    super
    @remote_actions = []
  end

  alias_method :original_enhance, :enhance
  def enhance(deps=nil, &block)
    original_enhance(deps)
    @remote_actions << Action.new(self, block) if block_given?
    self
  end

  def execute
    raise Vlad::ConfigurationError, "No target hosts specified for task: #{self.name}" if target_hosts.empty?
    super
    @remote_actions.each { |act| act.execute(target_hosts) }
  end

  def rsync local, remote
    cmd = ['rsync', '-aqz', '--delete', local, "#{@target_host}:#{remote}"]

    success = system(*cmd)

    unless success then
      raise Vlad::CommandFailedError, "execution failed: #{cmd.join ' '}"
    end
  end

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

  def sudo command
    run "sudo #{command}"
  end

  def target_hosts
    if hosts = ENV["HOSTS"]
      hosts.strip.gsub(/\s+/,'').split(",")
    else
      roles = options[:roles]
      roles ? Rake::RemoteTask.hosts_for(roles) : Rake::RemoteTask.all_hosts
    end
  end

  def self.all_hosts
    hosts_for(@@roles.keys)
  end

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

  def self.host host_name, *roles
    opts = Hash === roles.last ? roles.pop : {}

    roles.each do |role_name|
      role role_name, host_name, opts.dup
    end
  end

  def self.hosts_for *roles
    roles.flatten.map do |r|
      @@roles[r].keys
    end.flatten.uniq.sort
  end

  def self.load path
    Kernel.load path
    require 'vlad_tasks'
  end

  def self.protect_env name
    @@env_locks[name.to_s].synchronize do
      yield
    end
  end

  def self.reserved_name? name
    !@@env.has_key?(name.to_s) && self.respond_to?(name)
  end

  def self.task
    Thread.current[:task]
  end

  def self.roles; @@roles; end
  def self.tasks; @@tasks; end
  def self.env  ; @@env  ; end

  def self.reset
    @@roles = Hash.new { |h,k| h[k] = {} }
    @@env = {}
    @@tasks = {}
    @@env_locks = Hash.new { |h,k| h[k] = Mutex.new }

    set(:application) { raise Vlad::ConfigurationError, "Please specify the name of the application" }
    set(:repository)  { raise Vlad::ConfigurationError, "Please specify the repository path" }
    set(:deploy_to)   { raise Vlad::ConfigurationError, "Please specify the deploy path" }

    set(:current_path)    { File.join(deploy_to, "current") }
    set(:current_release) { File.join(releases_path, releases.last) }
    set(:deploy_timestamped, true)
    set(:deploy_via, :export)
    set(:latest_release)  { deploy_timestamped ? release_path : current_release }
    set(:migrate_env, "")
    set(:migrate_target, :latest)
    set(:rails_env, "production")
    set(:rake, "rake")
    set(:release_name)    { Time.now.utc.strftime("%Y%m%d%H%M%S") }
    set(:release_path)    { File.join(releases_path, release_name) }
    set(:releases)        { task.run("ls -x #{releases_path}").split.sort }
    set(:releases_path)   { File.join(deploy_to, "releases") }
    set(:scm, :subversion)
    set(:scm_path)        { File.join(deploy_to, "scm") }
    set(:shared_path)     { File.join(deploy_to, "shared") }
    set(:user, "nobody")

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
      scm = fetch(:scm)
      require "vlad/#{scm}"
      Vlad.const_get(scm.to_s.capitalize).new
    end
  end

  def self.role role_name, host, args = {}
    raise ArgumentError, "invalid host" if host.nil? or host.empty?
    @@roles[role_name][host] = args
  end

  def self.remote_task name, options = {}, &b
    t = Rake::RemoteTask.define_task(name, &b)
    t.options = options
    roles = options[:roles]
    t
  end

  class Action
    attr_reader :task, :block, :workers

    def initialize task, block
      @task  = task
      @block = block
      @workers = []
    end

    def == other
      return false unless Action === other
      block == other.block && task == other.task
    end

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

