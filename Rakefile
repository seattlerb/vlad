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
  mock "subversion"
end

task :mock_p4 do
  mock "perforce"
end

task :flog do
  sh 'find lib -name \*.rb | grep -v vlad_tasks | xargs flog | head -1'
end

task :flog_full do
  sh 'find lib -name \*.rb | xargs flog'
end

task :sort do
  begin
    sh 'for f in lib/*.rb; do echo $f; grep "^ *def " $f | grep -v sort=skip > x; sort x > y; echo $f; echo; diff x y; done'
    sh 'for f in test/test_*.rb; do echo $f; grep "^ *def.test_" $f > x; sort x > y; echo $f; echo; diff x y; done'
  ensure
    sh 'rm x y'
  end
end

def mock(svc)
  if svc == "subversion" then
    sh "svnadmin create svnrepo" unless test ?d, 'svnrepo'
    sh "svn co file:///#{Dir.pwd}/svnrepo blah"
    sh 'rails blah' unless test ?f, 'blah/Rakefile'
  else
    sh 'rails blah' unless test ?d, 'blah'
  end

  path = 'blah/config/deploy.rb'
  File.open path, 'w' do |f|
    f.write <<-"EOM"
# required
set :application, "blah"
set :deploy_to, "#{File.expand_path File.join(Dir.pwd, '..', 'blah-'+svc.to_s)}/seattlerb.org"
set :domain, "localhost"
#{"#" unless svc == "perforce"}set :repository, "#\{deploy_to}/scm"
#{"#" unless svc == "subversion"}set :repository, 'file:///#{Dir.pwd}/svnrepo'

# optional
set :scm, '#{svc}'
set :user, "ryan"


remote_task :check do
  run "ls"
end
EOM
  end unless test ?f, path

  path = 'blah/Rakefile'
  File.open path, 'a' do |f|
    f.puts
    f.puts "$: << '#{Dir.pwd}/lib'"
    f.puts "require 'vlad'"
    f.puts "Vlad.load 'config/deploy.rb'"
  end unless File.read(path) =~ /vlad/
  sh "cat #{path}"

  if svc == "subversion" then
    sh "(cd blah && svn add * && svn ci -m 'woot')"
  end

  Dir.chdir "blah" do
    sh "rake -t -T vlad"
    sh "rake -t vlad:setup"
    sh "rake -t vlad:update"
  end
end

# vim: syntax=Ruby
