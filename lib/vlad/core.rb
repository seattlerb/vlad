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
    y Rake::RemoteTask.env
    puts "# Roles:"
    y Rake::RemoteTask.roles
  end

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
    dirs = [deploy_to, releases_path, scm_path, shared_path]
    dirs += shared_paths.keys.map { |d| File.join(shared_path, d) }
    run "umask #{umask} && mkdir -p #{dirs.join(' ')}"
  end

  desc "Updates your application server to the latest revision.  Syncs
    a copy of the repository, exports it as the latest release, fixes
    up your symlinks, symlinks the latest revision to current and logs
    the update.".cleanup

  remote_task :update, :roles => :app do
    symlink = false
    begin
      run [ "cd #{scm_path}",
            "#{source.checkout revision, scm_path}",
            "#{source.export revision, release_path}",
            "chmod -R g+w #{latest_release}",
            "rm -rf #{shared_paths.values.map { |p| File.join(latest_release, p) }.join(' ')}",
            "mkdir -p #{mkdirs.map { |d| File.join(latest_release, d) }.join(' ')}"
          ].join(" && ")
      Rake::Task['vlad:update_symlinks'].invoke

      symlink = true
      run "rm -f #{current_path} && ln -s #{latest_release} #{current_path}"

      run "echo #{now} $USER #{revision} #{File.basename release_path} >> #{deploy_to}/revisions.log"
    rescue => e
      run "rm -f #{current_path} && ln -s #{previous_release} #{current_path}" if
        symlink
      run "rm -rf #{release_path}"
      raise e
    end
  end

  desc "Updates the symlinks for shared paths".cleanup

  remote_task :update_symlinks, :roles => :app do
    ops = shared_paths.map do |sp, rp|
      "ln -s #{shared_path}/#{sp} #{latest_release}/#{rp}"
    end
    run ops.join(' && ')
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

  remote_task :rollback do
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

  remote_task :cleanup do
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
