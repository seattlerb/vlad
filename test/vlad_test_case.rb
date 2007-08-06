require 'test/unit'
require 'vlad'

class Rake::RemoteTask
  attr_accessor :commands, :action

  def system(command)
    @commands << command
    self.action ? self.action[command] : true
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
