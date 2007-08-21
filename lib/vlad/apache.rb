require 'vlad'

namespace :vlad do
  ##
  # Apache web server

  set :web_command, "apachectl"

  desc "Restart the web servers"

  remote_task :start_web, :roles => :web  do
    run "#{web_command} restart"
  end

  desc "Stop the web servers"

  remote_task :stop_web, :roles => :web  do
    run "#{web_command} stop"
  end

  ##
  # Everything HTTP.

  desc "Restart the web and app servers"

  remote_task :start do
    Rake::Task['vlad:start_app'].invoke
    Rake::Task['vlad:start_web'].invoke
  end

  desc "Stop the web and app servers"

  remote_task :stop do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:stop_web'].invoke
  end
end
