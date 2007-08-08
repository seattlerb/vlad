# -*- ruby -*-

require 'rubygems'
require 'hoe'
$: << 'lib'
require 'vlad'

Hoe.new('vlad', Vlad::VERSION) do |p|
  p.rubyforge_name = 'vlad'
  # p.author = 'FIX'
  # p.email = 'FIX'
  # p.summary = 'FIX'
  # p.description = p.paragraphs_of('README.txt', 2..5).join("\n\n")
  # p.url = p.paragraphs_of('README.txt', 0).first.split(/\n/)[1..-1]
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps << 'rake'
  p.extra_deps << 'open4'
end

task :mock_svn do
  sh 'rails blah' unless test ?d, 'blah'

  path = 'blah/config/deploy.rb'
  File.open path, 'w' do |f|
    f.write <<-"EOM"
set :application, "blah"
set :remote_home, "#{File.expand_path File.join(Dir.pwd, '..', 'blah-svn')}"
set :user, "ryan"
set :deploy_to, "#\{remote_home}/seattlerb.org"
set :use_sudo, false
set :domain, "localhost"

set :scm, 'svn'
set :repository, 'svn://rubyforge.org/var/svn/seattlerb'

host domain, :app, :web, :db

remote_task :check do
  run "ls"
end
EOM
  end unless test ?f, path

  path = 'blah/Rakefile'
  File.open path, 'a' do |f|
    f.puts
    f.puts "$: << '../lib'"
    f.puts "require 'vlad'"
    f.puts "Vlad.load 'config/deploy.rb'"
  end unless File.read(path) =~ /vlad/
  sh "cat #{path}"

  Dir.chdir "blah" do
    sh "rake -t -T vlad"
    sh "rake -t vlad:setup"
    sh "rake -t vlad:update"
  end
end

task :flog do
  sh 'find lib -name \*.rb | grep -v vlad_tasks | xargs flog | head -1'
end

task :flog_full do
  sh 'find lib -name \*.rb | xargs flog | head -1'
end

task :sort do
  begin
    sh 'for f in lib/*.rb; do echo $f; grep "^ *def " $f | grep -v sort=skip > x; sort x > y; echo $f; echo; diff x y; done'
    sh 'for f in test/test_*.rb; do echo $f; grep "^ *def.test_" $f > x; sort x > y; echo $f; echo; diff x y; done'
  ensure
    sh 'rm x y'
  end
end

# vim: syntax=Ruby
