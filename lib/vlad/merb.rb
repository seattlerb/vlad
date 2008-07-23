require 'vlad'

namespace :vlad do
  ##
  # Merb app server

  set :merb_address,       "127.0.0.1"
  set :merb_command,       'merb'
  set :merb_environment,   "production"
  set :merb_port,          8000
  set :merb_servers,       2

  # maybe needed later
  #set :merb_clean,         false
  #set(:merb_conf)          { "#{current_path}/config/merb.yml" }
  #set :merb_config_script, nil
  #set :merb_group,         nil
  #set :merb_log_file,      nil
  #set :merb_pid_file,      nil
  #set :merb_prefix,        nil
  #set :merb_user,          nil

  desc "Start the app servers"
  remote_task :start_app, :roles => :app do
    cmd = [
            "cd #{current_path} &&", # work around merb bug,
                                     # http://merb.devjavu.com/ticket/469
            "#{merb_command}",
          #"-m #{current_path}",     # the buggy behaviour
            "-e #{merb_environment}",
            "-p #{merb_port}",
            "-c #{merb_servers}"
          ].compact.join ' '
    run cmd
  end

  desc "Stop the app servers"
  remote_task :stop_app, :roles => :app do
    merb_servers.times do |i|
      cmd = "#{current_path}/script/stop_merb #{merb_port + i}"
      puts "$ #{cmd}"
      run cmd
    end
  end
  
  desc "Stop, then restart the app servers"
  remote_task :restart_app, :roles => :app do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:start_app'].invoke
  end
end