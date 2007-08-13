require 'vlad'

class String #:nodoc:
  def cleanup
    if ENV['FULL'] then
      gsub(/\s+/, ' ').strip
    else
      self[/\A.*?\./]
    end
  end
end

##
# Ideal scenarios:
#
# Initial:
#
# 1) rake vlad:setup
# 2) rake vlad:update
# 3) rake vlad:migrate
# 4) rake vlad:start
#
# Subsequent:
#
# 1) rake vlad:update
# 2) rake vlad:migrate (optional)
# 3) rake vlad:start

namespace :vlad do
  desc "Show the vlad setup.  This is all the default variables for vlad
    tasks.".cleanup
  task :debug do
    require 'yaml'
    y Vlad.instance
  end

  # used by update, out here so we can ensure all threads have the same value
  now = Time.now.utc.strftime("%Y%m%d%H%M.%S")

  desc "Updates your application server to the latest revision.  Syncs a copy
    of the repository, exports it as the latest release, fixes up your
    symlinks, touches your assets, symlinks the latest revision to current and
    logs the update.".cleanup

  remote_task :update, :roles => :app do
    symlink = false
    begin
      # TODO: head/version should be parameterized
      run [ "cd #{scm_path}",
            "#{source.checkout "head", '.'}",
            "#{source.export ".", release_path}",
            "chmod -R g+w #{latest_release}",
            "rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids",
            "mkdir -p #{latest_release}/db #{latest_release}/tmp",
            "ln -s #{shared_path}/log #{latest_release}/log",
            "ln -s #{shared_path}/system #{latest_release}/public/system",
            "ln -s #{shared_path}/pids #{latest_release}/tmp/pids",
          ].join(" && ")

      asset_paths = %w(images stylesheets javascripts).map { |p| "#{latest_release}/public/#{p}" }.join(" ")
      run "find #{asset_paths} -exec touch -t #{now} {} ';'; true"

      symlink = true
      run "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"
      # Rake::Task["vlad:migrate"].invoke

      run "echo #{now} $USER #{'head'} #{File.basename release_path} >> #{deploy_to}/revisions.log" # FIX shouldn't be head
    rescue => e
      run "rm -f #{current_path} && ln -s #{previous_release} #{current_path}" if
        symlink
      run "rm -rf #{release_path}"
      raise e
    end
  end

  desc "Run the migrate rake task for the the app. By default this is run in
    the latest app directory.  You can run migrations for the current app
    directory by setting :migrate_target to :current.  Additional environment
    variables can be passed to rake via the migrate_env variable.".cleanup

  # HACK :only => { :primary => true }
  # No application files are on the DB machine, also migrations should only be
  # run once.
  remote_task :migrate, :roles => :app do
    directory = case migrate_target.to_sym
                when :current then current_path
                when :latest  then current_release
                else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
                end

    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_args} db:migrate"
  end

  desc "Invoke a single command on every remote server. This is useful for
    performing one-off commands that may not require a full task to be written
    for them.  Simply specify the command to execute via the COMMAND
    environment variable.  To execute the command only on certain roles,
    specify the ROLES environment variable as a comma-delimited list of role
    names.

      $ rake vlad:invoke COMMAND='uptime'".cleanup

  remote_task :invoke do
    command = ENV["COMMAND"]
    abort "Please specify a command to execute on the remote servers (via the COMMAND environment variable)" unless command
    puts run(command)
  end

  desc "Copy files to the currently deployed version. This is useful for
    updating files piecemeal when you need to quickly deploy only a single
    file.

    To use this task, specify the files and directories you want to copy as a
    comma-delimited list in the FILES environment variable. All directories
    will be processed recursively, with all files being pushed to the
    deployment servers. Any file or directory starting with a '.' character
    will be ignored.

      $ rake vlad:upload FILES=templates,controller.rb".cleanup

  remote_task :upload do
    files = (ENV["FILES"] || "").
      split(",").
      map { |f| f.strip!; File.directory?(f) ? Dir["#{f}/**/*"] : f }.
      flatten.
      reject { |f| File.directory?(f) || File.basename(f)[0] == ?. }

    abort "Please specify at least one file to update (via the FILES environment variable)" if files.empty?

    files.each do |file|
      put File.read(file), File.join(current_path, file)
    end
  end

  desc "Rolls back to a previous version and restarts. This is handy if you
    ever discover that you've deployed a lemon; 'rake vlad:rollback' and
    you're right back where you were, on the previously deployed
    version.".cleanup

  remote_task :rollback do
    if releases.length < 2 then
      abort "could not rollback the code because there is no prior release"
    else
      run "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
    end

    Rake::Task['vlad:restart'].invoke
  end

  desc "Clean up old releases. By default, the last 5 releases are kept on
    each server (though you can change this with the keep_releases variable).
    All other deployed revisions are removed from the servers.".cleanup

  remote_task :cleanup do
    count = fetch(:keep_releases, 5).to_i
    if count >= releases.length then
      puts "no old releases to clean up"
    else
      puts "keeping #{count} of #{releases.length} deployed releases"

      directories = (releases - releases.last(count)).map { |release|
        File.join(releases_path, release)
      }.join(" ")

      invoke_command "rm -rf #{directories}"
    end
  end

  ##
  # Mongrel app server

  set :mongrel_address, "127.0.0.1"
  set :mongrel_clean, false
  set :mongrel_command, 'mongrel_rails'
  set :mongrel_conf, "/etc/mongrel_cluster/#{application}.conf"
  set :mongrel_config_script, nil
  set :mongrel_environment, "production"
  set :mongrel_group, nil
  set :mongrel_log_file, nil
  set :mongrel_pid_file, nil
  set :mongrel_port, 8000
  set :mongrel_prefix, nil
  set :mongrel_servers, 2
  set :mongrel_user, nil

  desc "Prepares application servers for deployment. Before you can use any of
    the deployment tasks with your project, you will need to make sure all of
    your servers have been prepared with 'rake setup'. It is safe to run this
    task on servers that have already been set up; it will not destroy any
    deployed revisions or data. mongrel configuration is set via the mongrel_*
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

  desc "Restart mongrel processes on the app servers by starting and
    stopping the cluster.".cleanup

  remote_task :start_app, :roles => :app do
    cmd = "#{mongrel_command} cluster::restart -C #{mongrel_conf}"
    cmd << ' --clean' if mongrel_clean
    run cmd
  end

  desc "Stop mongrel processes on the app servers."

  remote_task :stop_app, :roles => :app do
    cmd = "#{mongrel_command} cluster::stop -C #{mongrel_conf}"
    cmd << ' --clean' if mongrel_clean
    run cmd
  end

  ##
  # Apache web server

  set :web_command, "apachectl"

  desc "Restart web server."
  remote_task :restart_web, :roles => :web  do
    run "#{web_command} restart"
  end

  desc "Stop web server."
  remote_task :stop_web, :roles => :web  do
    run "#{web_command} stop"
  end

  ##
  # Everything HTTP.

  desc "Restart web and app server"
  remote_task :start do
    Rake::Task['vlad:restart_app'].invoke
    Rake::Task['vlad:restart_web'].invoke
  end

  desc "Stop web and app server"
  remote_task :stop do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:stop_web'].invoke
  end

end # namespace vlad
