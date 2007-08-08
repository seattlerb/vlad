require 'test/unit'
require 'stringio'
require 'vlad'

class StringIO
  def readpartial(size) read end # suck!
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

    yield 42, @input, out, err

    status = self.action ? self.action[command.join(' ')] : 0
    Status.new status
  end

  def select reads, writes, errs, timeout
    [reads, writes, errs]
  end

end

class VladTestCase < Test::Unit::TestCase
  undef_method :default_test

  def setup
    @vlad = Vlad.instance
    Rake.application.clear
    @task_count = Rake.application.tasks.size
  end

  def teardown
    @vlad.env.keys.each { |k| Object.send(:remove_method, k) if @vlad.respond_to?(k) }
    @vlad.reset
  end

  def util_set_hosts
    @vlad.host "app.example.com", :app
    @vlad.host "db.example.com", :db
  end
end
