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
  src_dir = Dir.pwd
  Dir.chdir "/tmp/"

  case svc
  when "subversion" then
    sh "svnadmin create svnrepo" unless test ?d, 'svnrepo'
    sh "svn co file:///tmp/svnrepo blah"
  when "perforce" then
    sh "mkdir p4repo" unless test ?d, 'p4repo'
    sh "(cd /tmp; p4d -r /tmp/p4repo -p localhost:1666 -d)"
  else
    raise "huh?"
  end

  sh 'rails blah' unless test ?f, 'blah/Rakefile'

  path = 'blah/config/deploy.rb'
  File.open path, 'w' do |f|
    f.write <<-"EOM"
# required
set :application, "blah"
set :deploy_to, "/tmp/blah-#{svc}"
set :domain, "localhost"
#{"#" unless svc == "perforce"}set :repository, "#\{deploy_to}/scm"
#{"#" unless svc == "perforce"}set :p4pass, "password"
#{"#" unless svc == "perforce"}set :p4user, "ryan"
#{"#" unless svc == "subversion"}set :repository, 'file:///tmp/svnrepo'

# optional
set :scm, '#{svc}'

remote_task :check do
  run "ls"
end
EOM
  end unless test ?f, path

  path = 'blah/Rakefile'
  File.open path, 'a' do |f|
    f.puts
    f.puts "$: << '#{src_dir}/lib'"
    f.puts "require 'vlad'"
    f.puts "Vlad.load 'config/deploy.rb'"
  end unless File.read(path) =~ /vlad/

  case svc
  when "subversion" then
    sh "(cd blah && svn add * && svn ci -m 'woot')"
  when "perforce" then
    # nothing to do -- you must manually set up a user, client, and submit blah
    abort "set up p4 user/client and check in blah" unless
      test ?d, 'p4repo/depot'
  end

  Dir.chdir "blah" do
    sh "rake -t vlad:setup"
    sh "rake -t vlad:update"
    sh "rake -t vlad:migrate"
    sh "rake -t vlad:start"
  end
end

desc 'go'
task :go do
  sh "rm -rf /tmp/blah /tmp/svnrepo /tmp/blah-subversion && rake mock_svn"
end

desc 'go2'
task :go2 do
  sh "killall p4d ; rm -rf /tmp/blah"
  Rake::Task["mock_p4"].invoke
end

#   501  cd /tmp/
#   502  l
#   503  cd blah/
#   506  new_perforce localhost 1666 blah
#   507  la
#   508  l localhost/
#   509  find localhost/
#   510  mv localhost/.p4config .
#   511  rmdir localhost/
#   512  l
#   513  cat .p4config
#   514  p4 user
#   515  p4 client
#   516  p4 sync
#   517  find . -type f | xargs p4 add
#   518  p4 submit ...
#   519  history

# vim: syntax=Ruby
