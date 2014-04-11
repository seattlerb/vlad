# -*- ruby -*-

require 'rubygems'
require 'hoe'

Hoe.plugin :seattlerb
Hoe.plugin :isolate

Hoe.add_include_dirs "../../rake-remote_task/dev/lib"

Hoe.spec 'vlad' do
  developer 'Ryan Davis',       'ryand-ruby@zenspider.com'
  developer 'Eric Hodel',       'drbrain@segment7.net'
  developer 'Wilson Bilkovich', 'wilson@supremetyrant.com'

  dependency 'rake',             ['>= 0.8', '< 11.0']
  dependency 'rake-remote_task', '~> 2.1'

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
