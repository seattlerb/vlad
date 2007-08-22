require 'rubygems'
require 'thread'
require 'rake_remote_task'

$TESTING ||= false

##
# Vlad the Deployer - Pragmatic application deployment automation, without mercy.
#
# Please read doco/getting_started.txt or http://rubyhitsquad.com/
#
# === Basic scenario:
#
# 1. rake vlad:setup   (first time only)
# 2. rake vlad:update
# 3. rake vlad:migrate (optional)
# 4. rake vlad:start

module Vlad

  ##
  # This is the version of Vlad you are running.
  VERSION = '1.0.1'

  ##
  # Base error class for all Vlad errors.
  class Error < RuntimeError; end

  ##
  # Raised when you have incorrectly configured Vlad.
  class ConfigurationError < Error; end

  ##
  # Raised when a remote command fails.
  class CommandFailedError < Error; end

  ##
  # Raised when an environment variable hasn't been set.
  class FetchError < Error; end

  ##
  # Loads tasks file +tasks_file+ and various recipe styles as a hash
  # of category/style pairs. +tasks_file+ defaults to
  # 'config/deploy.rb'. Recipes default to:
  #
  #     :core => :core
  #     :app  => :mongrel
  #     :web  => :apache
  #
  # You can override individual values and/or set to nil to
  # deactivate. You may also pass nil/false to turn off recipe loading
  # entirely so you can do your own thing.
  def self.load tasks_file = 'config/deploy.rb', recipes = {}
    if recipes then
      recipes = {
        :core => :core,
        :app => :mongrel,
        :web => :apache,
      }.merge recipes
      recipes.each do |_, recipe|
        require "vlad/#{recipe}" if recipe
      end
    end
    Kernel.load tasks_file
  end

end

class String #:nodoc:
  def cleanup
    if ENV['FULL'] then
      gsub(/\s+/, ' ').strip
    else
      self[/\A.*?\./]
    end
  end
end
