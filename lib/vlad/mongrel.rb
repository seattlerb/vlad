require 'vlad'

namespace :vlad do
  ##
  # Mongrel app server

  set :mongrel_address, "127.0.0.1"
  set :mongrel_clean, false
  set :mongrel_command, 'mongrel_rails'
  set(:mongrel_conf) { "#{shared_path}/mongrel_cluster.conf" }
  set :mongrel_config_script, nil
  set :mongrel_environment, "production"
  set :mongrel_group, nil
  set :mongrel_log_file, nil
  set :mongrel_pid_file, nil
  set :mongrel_port, 8000
  set :mongrel_prefix, nil
  set :mongrel_servers, 2
  set :mongrel_user, nil

  desc "Prepares application servers for deployment. Mongrel configuration is set via the mongrel_*
    variables.".cleanup

  remote_task :setup_app, :roles => :app do
    dirs = [deploy_to, releases_path, scm_path, shared_path]
    dirs += %w(system log pids).map { |d| File.join(shared_path, d) }
    run "umask 02 && mkdir -p #{dirs.join(' ')}"

    cmd = [
           "#{mongrel_command} cluster::configure",
           "-N #{mongrel_servers}",
           "-p #{mongrel_port}",
           "-e #{mongrel_environment}",
           "-a #{mongrel_address}",
           "-c #{current_path}",
           "-C #{mongrel_conf}",
           ("-P #{mongrel_pid_file}" if mongrel_pid_file),
           ("-l #{mongrel_log_file}" if mongrel_log_file),
           ("--user #{mongrel_user}" if mongrel_user),
           ("--group #{mongrel_group}" if mongrel_group),
           ("--prefix #{mongrel_prefix}" if mongrel_prefix),
           ("-S #{mongrel_config_script}" if mongrel_config_script),
            ].compact.join ' '

    run cmd
  end

  desc "Restart the app servers"

  remote_task :start_app, :roles => :app do
    cmd = "#{mongrel_command} cluster::restart -C #{mongrel_conf}"
    cmd << ' --clean' if mongrel_clean
    run cmd
  end

  desc "Stop the app servers"

  remote_task :stop_app, :roles => :app do
    cmd = "#{mongrel_command} cluster::stop -C #{mongrel_conf}"
    cmd << ' --clean' if mongrel_clean
    run cmd
  end
end
