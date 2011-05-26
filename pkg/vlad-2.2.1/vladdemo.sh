#!/bin/bash

N=$1; shift

killall mongrel svnserve 2> /dev/null

rm -rf ~/demo
mkdir ~/demo
cd ~/demo

pause() {
  echo -n "waiting... hit return... "
  read
  echo
}

echo "Starting demo from scratch"
echo "  This step creates a subversion repository and imports a new rails app"
echo "  It modifies the Rakefile to load Vlad and creates config/deploy.rb"
echo
pause

svnadmin create svnrepo
echo "anon-access = write" >> svnrepo/conf/svnserve.conf

svnserve -d --foreground -r svnrepo --listen-host localhost &

echo "cd ~/demo
rm -rf website_*
svnserve -d --foreground -r svnrepo --listen-host localhost &

cd mydemoapp
ruby -I ~/Work/p4/zss/src/vlad/dev/lib -S rake -t vlad:setup vlad:update

kill %1" > go.sh
chmod u+x go.sh

rails mydemoapp

cd mydemoapp

echo "require 'rubygems'
require 'vlad'
Vlad.load" >> Rakefile

echo "set :repository, 'svn://localhost/blah'
set :domain, 'localhost'
set :web_command, 'sudo apachectl'" > config/deploy.rb

# TODO: add a knob
if [ -n "$N" ]; then
    echo "set(:deploy_to, :per_thread) {
  File.expand_path(\"~/demo/website_#{target_host}\")
}

%w(current_path current_release latest_release
   previous_release releases_path release_path
   scm_path shared_path).each do |name|
  Rake::RemoteTask.per_thread[name] = true
end

(1..$N).each do |n|
  host 'localhost%02d' % n, :web, :app
end" >> config/deploy.rb
else
    echo "set :deploy_to, File.expand_path('~/demo/website')" >> config/deploy.rb
fi

svn import -m Added . svn://localhost/blah

echo
echo "Here is your config:"
cat config/deploy.rb
echo
echo "Here are the tasks available:"
echo

ruby -I ~/Work/p4/zss/src/vlad/dev/lib -S rake -T vlad

echo
echo "The next step deploys and fires up the application"
echo
pause

ruby -I ~/Work/p4/zss/src/vlad/dev/lib -S rake -t vlad:setup vlad:update vlad:start

open http://localhost:8000/

echo
echo "done! check it out"
echo
pause

ruby -I ~/Work/p4/zss/src/vlad/dev/lib -S rake vlad:stop

kill %1

