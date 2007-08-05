require 'singleton'

class Vlad
  VERSION = '1.0.0'

  include Singleton

  def initialize
    @env = {}
    @roles = {}

    instance_eval File.read("config/deploy.rb")
  end

  def set name, val = nil, &b
    @env[name] = val || b
  end

  def role name, host, args = nil
    @roles[name] = [host, args]
  end

  def method_missing name, *other
    if @env.has_key? name and other.empty? then
      @env[name]
    else
      super
    end
  end
end
