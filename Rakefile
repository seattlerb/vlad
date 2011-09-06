# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.spec 'vlad' do
  self.rubyforge_name = 'hitsquad'

  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  dependency 'rake',             '~> 0.8'
  dependency 'rake-remote_task', '~> 2.0'
  dependency 'open4',            '~> 0.9.0'

  # TODO: remove 1.9
  multiruby_skip << "rubinius"
end

desc "quick little hack to see what the state of the nation looks like"
task :debug do
  $: << 'lib'
  require 'vlad'
  Vlad.load :config => "lib/vlad/subversion.rb"
  set :repository, "repository path"
  set :deploy_to,  "deploy path"
  set :domain,     "server domain"

  Rake::Task['vlad:debug'].invoke
end

# vim: syntax=ruby
