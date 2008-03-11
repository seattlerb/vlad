require 'test/unit'
require 'stringio'
require 'vlad'

class StringIO
  def readpartial(size) read end # suck!
end

module Process
  def self.expected status
    @@expected ||= []
    @@expected << status
  end

  class << self
    alias :waitpid2_old :waitpid2

    def waitpid2(pid)
      [ @@expected.shift ]
    end
  end
end


class Rake::RemoteTask
  attr_accessor :commands, :action, :input, :output, :error

  Status = Struct.new :exitstatus

  class Status
    def success?() exitstatus == 0 end
  end

  def system *command
    @commands << command
    self.action ? self.action[command.join(' ')] : true
  end

  def popen4 *command
    @commands << command

    @input = StringIO.new
    out = StringIO.new @output.shift.to_s
    err = StringIO.new @error.shift.to_s

    raise if block_given?

    status = self.action ? self.action[command.join(' ')] : 0
    Process.expected Status.new(status)

    return 42, @input, out, err
  end

  def select reads, writes, errs, timeout
    [reads, writes, errs]
  end

end

class VladTestCase < Test::Unit::TestCase
  undef_method :default_test

  def setup
    @vlad = Rake::RemoteTask
    @vlad.reset
    Rake.application.clear
    @task_count = Rake.application.tasks.size
    @vlad.set :domain, "example.com"
  end

  def util_set_hosts
    @vlad.host "app.example.com", :app
    @vlad.host "db.example.com", :db
  end
end
