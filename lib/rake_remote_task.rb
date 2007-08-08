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

  # -- HERE BE DRAGONS --
  # We are defining singleton methods on the task AS it executes
  # for each 'set' variable. We do this because we need to be support
  # 'application' and similar Rake-reserved names inside remote tasks.
  # This relies on the current (rake 0.7.3) calling conventions.
  # If this breaks blame Jim Weirich and/or society.
  def execute
    raise Vlad::ConfigurationError, "No target hosts specified for task: #{self.name}" if target_hosts.empty?
    super
    Vlad.instance.env.keys.each do |name|
      self.instance_eval "def #{name}; Vlad.instance.fetch('#{name}'); end"
    end
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
      roles ? Vlad.instance.hosts_for(roles) : Vlad.instance.all_hosts
    end
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
          task.instance_eval(&block)
        end
        @workers << thread
      end
      @workers.each { |w| w.join }
    end
  end
end
