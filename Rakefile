# -*- ruby -*-

require 'rubygems'
require 'hoe'
$: << 'lib'
require 'vlad'

Hoe.new('vlad', Vlad::VERSION) do |vlad|
  vlad.rubyforge_name = 'hitsquad'

  vlad.developer('Ryan Davis', 'ryand-ruby@zenspider.com')
  vlad.developer('Eric Hodel', 'drbrain@segment7.net')
  vlad.developer('Wilson Bilkovich', 'wilson@supremetyrant.com')

  vlad.extra_deps << ['rake', '>= 0.8.1']
  vlad.extra_deps << 'open4'

  vlad.multiruby_skip << "1.9" << "rubinius"
end

desc "quick little hack to see what the state of the nation looks like"
task :debug do
  Vlad.load :config => "lib/vlad/subversion.rb"
  set :repository, "repository path"
  set :deploy_to,  "deploy path"
  set :domain,     "server domain"

  Rake::Task['vlad:debug'].invoke
end

task :flog do
  sh 'flog -s lib'
end

task :flog_full do
  sh 'flog -a lib'
end

task :mana_from_heaven do
  # vlad = vlad + rake + open4
  # rake sans-contrib = 2035.98356718206
  vlad  = `flog -s lib`.to_f + 2350.30744806517 + 502.363818023761
  cap   = 11480.3919695285
  ratio = cap / vlad
  target = cap / Math::PI

  puts "%14.8f = %s" % [vlad, "vlad"]
  puts "%14.8f = %s" % [ratio, "ratio"]
  puts "%14.8f = %s" % [target - vlad, "needed delta"]
end

# vim: syntax=Ruby
