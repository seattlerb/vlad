#!/bin/bash

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

rails mydemoapp

cd mydemoapp

echo "require 'rubygems'
require 'vlad'
Vlad.load" >> Rakefile

echo "set :repository, 'svn://localhost/blah'
set :domain, 'localhost'
set :deploy_to, File.expand_path('~/demo/website')
set :web_command, 'sudo apachectl'" > config/deploy.rb

svn import -m Added . svn://localhost/blah

echo
echo "Here are the tasks available:"
echo

rake -T vlad

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

rake vlad:stop

kill %1

