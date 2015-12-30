require 'vlad'

##
# used by update, out here so we can ensure all threads have the same value
def now
  @now ||= Time.now.utc.strftime("%Y%m%d%H%M.%S")
end

namespace :vlad do
  desc "Show the vlad setup.  This is all the default variables for vlad
    tasks.".cleanup

  task :debug do
    require 'yaml'

    # force them into values
    Rake::RemoteTask.env.keys.each do |key|
      next if key =~ /_release|releases|sudo_password/
      Rake::RemoteTask.fetch key
    end

    puts "# Environment:"
    puts
    puts Rake::RemoteTask.env.to_yaml
    puts "# Roles:"
    puts Rake::RemoteTask.roles.to_yaml
  end

  append :ancillary_dir

  desc "Setup your servers. Before you can use any of the deployment
    tasks with your project, you will need to make sure all of your
    servers have been prepared with 'rake vlad:setup'. It is safe to
    run this task on servers that have already been set up; it will
    not destroy any deployed revisions or data.".cleanup

  task :setup do
    Rake::Task['vlad:setup_app'].invoke
  end

  desc "Prepares application servers for deployment.".cleanup

  remote_task :setup_app, :roles => :app do
    dirs = [deploy_to, releases_path, shared_path]
    dirs << scm_path unless skip_scm
    dirs += shared_paths.keys.map { |d| File.join(shared_path, d) }
    dirs += ancillary_dir

    commands = []

    commands << "umask #{umask}" if umask
    dirs.each { |dir| commands << "[ -f #{dir} ] || mkdir -p #{dir}" }

    commands << "chown #{perm_owner} #{dirs.join(' ')}" if perm_owner
    commands << "chgrp #{perm_group} #{dirs.join(' ')}" if perm_group

    run commands.join(' && ')
  end

  desc "Updates your application server to the latest revision.  Syncs
    a copy of the repository, exports it as the latest release, fixes
    up your symlinks, symlinks the latest revision to current and logs
    the update.".cleanup

  remote_task :update, :roles => :app do
    Rake::Task['vlad:update_app'].invoke
    Rake::Task['vlad:update_symlinks'].invoke
    Rake::Task['vlad:set_current_release'].invoke
    Rake::Task['vlad:log_revision'].invoke
  end

  desc "Updates your application server to the latest revision.  Syncs 
    a copy of the repository, exports it as the latest release".cleanup

  remote_task :update_app, :roles => :app do
    begin
      commands = []
      commands << "umask #{umask}" if umask
      unless skip_scm
        commands << "cd #{scm_path}"
        commands << "#{source.checkout revision, scm_path}"
      end
      commands << "#{source.export revision, release_path}"

      unless shared_paths.empty?
        commands << "rm -rf #{shared_paths.values.map { |p| File.join(latest_release, p) }.join(' ')}"
      end
      unless mkdirs.empty?
        dirs = mkdirs.map { |d| File.join(latest_release, d) }.join(' ')
        commands << "mkdir -p #{dirs}"
        commands << "chown -R #{perm_owner} #{dirs}" if perm_owner
        commands << "chgrp -R #{perm_group} #{dirs}" if perm_group
      end

      commands << "chown -R #{perm_owner} #{latest_release}" if perm_owner
      commands << "chgrp -R #{perm_group} #{latest_release}" if perm_group

      run commands.join(" && ")
    rescue => e
      run "rm -rf #{release_path}"
      raise e
    end
  end

  desc "Updates up your symlinks for shared path".cleanup

  remote_task :update_symlinks, :roles => :app do
    begin
      ops = []
      unless shared_paths.empty?
        shared_paths.each do |sp, rp|
          ops << "ln -s #{shared_path}/#{sp} #{latest_release}/#{rp}"
        end
      end
      run ops.join(' && ') unless ops.empty?
    rescue => e
      run "rm -rf #{release_path}"
      raise e
    end
  end

  desc "Sets the latest revision to current".cleanup

  remote_task :set_current_release, :roles => :app do
    begin
      ops = []
      ops << "rm -f #{current_path}"
      ops << "ln -s #{latest_release} #{current_path}"
      run ops.join(' && ') unless ops.empty?
    rescue => e
      run "rm -f #{current_path} && ln -s #{previous_release} #{current_path}"
      run "rm -rf #{release_path}"
      raise e
    end
  end

  desc "Log the update".cleanup
  
  remote_task :log_revision, :roles => :app do
    begin
      commands = []

      commands << "umask #{umask}" if umask

      commands += [
        "echo #{now} $USER #{revision} #{File.basename(release_path)} >> #{deploy_to}/revisions.log"
      ]

      commands << "chown #{perm_owner} #{deploy_to}/revisions.log" if perm_owner
      commands << "chgrp #{perm_group} #{deploy_to}/revisions.log" if perm_group

      run commands.join(' && ')
    rescue => e
      run "rm -f #{current_path} && ln -s #{previous_release} #{current_path}"
      run "rm -rf #{release_path}"
      raise e
    end
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
    run(command)
  end

  desc "Copy arbitrary files to the currently deployed version using
    FILES=a,b,c. This is useful for updating files piecemeal when you
    need to quickly deploy only a single file.

    To use this task, specify the files and directories you want to copy as a
    comma-delimited list in the FILES environment variable. All directories
    will be processed recursively, with all files being pushed to the
    deployment servers. Any file or directory starting with a '.' character
    will be ignored.

      $ rake vlad:upload FILES=templates,controller.rb".cleanup

  remote_task :upload do
    file_list = (ENV["FILES"] || "").split(",")

    files = file_list.map do |f|
      f = f.strip
      File.directory?(f) ? Dir["#{f}/**/*"] : f
    end.flatten

    files = files.reject { |f| File.directory?(f) || File.basename(f)[0] == ?. }

    abort "Please specify at least one file to update (via the FILES environment variable)" if files.empty?

    files.each do |file|
      rsync file, File.join(current_path, file)
    end
  end

  desc "Rolls back to a previous version and restarts. This is handy if you
    ever discover that you've deployed a lemon; 'rake vlad:rollback' and
    you're right back where you were, on the previously deployed
    version.".cleanup

  remote_task :rollback, :roles => :app do
    if releases.length < 2 then
      abort "could not rollback the code because there is no prior release"
    else
      run "rm -f #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
    end

    Rake::Task['vlad:start'].invoke
  end

  desc "Clean up old releases. By default, the last 5 releases are kept on
    each server (though you can change this with the keep_releases variable).
    All other deployed revisions are removed from the servers.".cleanup

  remote_task :cleanup, :roles => :app do
    max = keep_releases
    if releases.length <= max then
      puts "no old releases to clean up #{releases.length} <= #{max}"
    else
      puts "keeping #{max} of #{releases.length} deployed releases"

      directories = (releases - releases.last(max)).map { |release|
        File.join(releases_path, release)
      }.join(" ")

      run "rm -rf #{directories}"
    end
  end

end # namespace vlad
