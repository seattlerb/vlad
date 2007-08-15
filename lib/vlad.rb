require 'rubygems'
require 'thread'
require 'rake_remote_task'

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
  VERSION = '1.0.0'

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
  # Loads tasks file +tasks_file+ and the vlad_tasks file. Pass true
  # to override_tasks to prevent Vlad from loading the standard
  # recipes.
  def self.load tasks_file = 'config/deploy.rb', override_tasks = false
    Kernel.load tasks_file
    require 'vlad_tasks' unless override_tasks
  end
end
