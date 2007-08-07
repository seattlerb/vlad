require 'test/unit'
require 'stringio'
require 'vlad'

class StringIO
  def readpartial(size) read end # suck!
end

class Rake::RemoteTask
  attr_accessor :commands, :action, :outputs, :input

  Status = Struct.new :exitstatus

  class Status
    def success?() exitstatus == 0 end
  end

  def popen4 *command
    @commands << command

    @input = StringIO.new
    out = @outputs.empty? ? StringIO.new : StringIO.new(@outputs.shift)
    err = StringIO.new

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
    @vlad.reset
    Rake.application.clear
    @task_count = Rake.application.tasks.size
  end

  def util_set_hosts
    @vlad.host "app.example.com", :app
    @vlad.host "db.example.com", :db
  end
end
