require 'vlad'

namespace :vlad do
  ##
  # Nginx web server on Gentoo/Debian init.d systems FIX

  set :web_command, "/etc/init.d/nginx"

  remote_task :setup_app, :roles => :web do
    config_file = "/etc/nginx/vhosts/#{application}_#{environment}.conf"
    raise "not yet... must review this code"
    run [ "sudo test -e #{config_file} || ",
          "sudo sh -c \"ruby ",
          "  /etc/sliceconfig/install/interactive/nginx_config.rb ",
          "'#{app_domain}' '#{application}' '#{environment}' ",
          "'#{app_port}' '#{app_servers}' #{only_www ? 1 : 0} ",
          "> #{config_file}\""
        ].join(" ")
  end

  desc "(Re)Start the web servers"

  remote_task :start_web, :roles => :web  do
    run "#{web_command} restart"
    # TODO: run %Q(sudo #{web_command} configtest && sudo #{web_command} reload)
  end

  desc "Stop the web servers"

  remote_task :stop_web, :roles => :web  do
    run "#{web_command} stop"
  end

  ##
  # Everything HTTP.

  desc "(Re)Start the web and app servers"

  remote_task :start do
    Rake::Task['vlad:start_app'].invoke
    Rake::Task['vlad:start_web'].invoke
  end

  remote_task :stop do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:stop_web'].invoke
  end
end
