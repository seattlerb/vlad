# -*- ruby -*-

require 'rubygems'
require 'hoe'
$: << 'lib'
require 'vlad'

Hoe.new('vlad', Vlad::VERSION) do |p|
  p.rubyforge_name = 'hitsquad'
  p.author = ["Ryan Davis", "Eric Hodel", "Wilson Bilkovich"]
  p.email = "ryand-ruby@zenspider.com"
  p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/).map { |s| s.strip }[2..-1]
  p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  p.summary = p.paragraphs_of('README.txt', 2).join
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps << 'rake'
  p.extra_deps << 'open4'
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
