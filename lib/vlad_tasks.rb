require 'vlad'

class String
  def cleanup
    if ENV['FULL'] then
      gsub(/\s+/, ' ').strip
    else
      self[/\A.*?\./]
    end
  end
end

#
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
  desc "show the vlad setup"
  task :debug do
    y Vlad.instance
  end

  desc "DOC: Prepares one or more servers for deployment. Before you can
    use any of the deployment tasks with your project, you will need
    to make sure all of your servers have been prepared with 'rake
    setup'. It is safe to run this task on servers that have already
    been set up; it will not destroy any deployed revisions or
    data.".cleanup

  remote_task :setup do
    dirs = [deploy_to, releases_path, scm_path, shared_path]
    dirs += %w(system log pids).map { |d| File.join(shared_path, d) }
    run "umask 02 && mkdir -p #{dirs.join(' ')}"
  end

  # used by update, out here so we can ensure all threads have the same value
  now = Time.now.utc.strftime("%Y%m%d%H%M.%S")

  desc "Updates the scm directory, rsyncs to the new release
  directory, and rolls symlinks".cleanup
  remote_task :update do
    set :migrate_target, :latest
    symlink = false
    begin
      # TODO: head/version should be parameterized
      run [ "cd #{scm_path}",
            "#{source.checkout "head", '.'}",
            "#{source.export ".", release_path}",
            "chmod -R g+w #{latest_release}",
            "rm -rf #{latest_release}/log #{latest_release}/public/system #{latest_release}/tmp/pids",
            "mkdir -p #{latest_release}/public #{latest_release}/tmp",
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

  desc "DOC: Run the migrate rake task. By default, it runs this in most recently
    deployed version of the app. However, you can specify a different release
    via the migrate_target variable, which must be one of :latest (for the
    default behavior), or :current (for the release indicated by the
    'current' symlink). Strings will work for those values instead of symbols,
    too. You can also specify additional environment variables to pass to rake
    via the migrate_env variable. Finally, you can specify the full path to the
    rake executable by setting the rake variable. The defaults are:

      set :rake,           'rake'
      set :rails_env,      'production'
      set :migrate_env,    ''
      set :migrate_target, :latest".cleanup

  remote_task :migrate, :roles => :db do # HACK :only => { :primary => true }
    directory = case migrate_target.to_sym
                when :current then current_path
                when :latest  then current_release
                else raise ArgumentError, "unknown migration target #{migrate_target.inspect}"
                end

    run "cd #{directory}; #{rake} RAILS_ENV=#{rails_env} #{migrate_env} db:migrate"
  end

  desc "DOC: Start the application servers. This will attempt to invoke a
    script in your application called 'script/spin', which must know
    how to start your application listeners. For Rails applications,
    you might just have that script invoke 'script/process/spawner'
    with the appropriate arguments.

    By default, the script will be executed via sudo as the 'app'
    user. If you wish to run it as a different user, set the :runner
    variable to that user. If you are in an environment where you
    can't use sudo, set the :use_sudo variable to false.".cleanup

  remote_task :start, :roles => :app do
    # TODO: extend run to automatically handle sudo and user options
    run "cd #{current_path} && nohup script/spin"
  end

  desc "DOC: Restarts your application. This works by calling the
    script/process/reaper script under the current path. By default,
    this will be invoked via sudo, but if you are in an environment
    where sudo is not an option, or is not allowed, you can indicate
    that restarts should use 'run' instead by setting the 'use_sudo'
    variable to false:

      set :use_sudo, false".cleanup

  remote_task :restart, :roles => :app do
    invoke_command "#{current_path}/script/process/reaper", :via => run_method
  end

  desc "DOC: Stop the application servers. This will call
    script/process/reaper for both the spawner process, and all of the
    application processes it has spawned. As such, it is fairly Rails
    specific and may need to be overridden for other systems.

    By default, the script will be executed via sudo as the 'app'
    user. If you wish to run it as a different user, set the :runner
    variable to that user. If you are in an environment where you
    can't use sudo, set the :use_sudo variable to false.".cleanup

  remote_task :stop, :roles => :app do
    run("#{current_path}/script/process/reaper -a kill -r dispatch.spawner.pid " +
        "|| #{current_path}/script/process/reaper -a kill")
  end

  desc "DOC: Invoke a single command on the remote servers. This is useful
  for performing one-off commands that may not require a full task to
  be written for them.  Simply specify the command to execute via the
  COMMAND environment variable.  To execute the command only on
  certain roles, specify the ROLES environment variable as a
  comma-delimited list of role names.

    $ rake vlad:invoke COMMAND='uptime'".cleanup

  remote_task :invoke do
    command = ENV["COMMAND"]
    abort "Please specify a command to execute on the remote servers (via the COMMAND environment variable)" unless command
    puts run(command)
  end

  desc "DOC: Updates the symlink to the most recently deployed
    version. Capistrano works by putting each new release of your
    application in its own directory. When you deploy a new version,
    this task's job is to update the 'current' symlink to point at the
    new version. You will rarely need to call this task directly;
    instead, use the 'deploy' task (which performs a complete deploy,
    including 'restart') or the 'update' task (which does everything
    except 'restart').".cleanup

  remote_task :symlink do
  end

  desc "DOC: Copy files to the currently deployed version. This is useful
    for updating files piecemeal, such as when you need to quickly
    deploy only a single file. Some files, such as updated templates,
    images, or stylesheets, might not require a full deploy, and
    especially in emergency situations it can be handy to just push
    the updates to production, quickly.

    To use this task, specify the files and directories you want to
    copy as a comma-delimited list in the FILES environment
    variable. All directories will be processed recursively, with all
    files being pushed to the deployment servers. Any file or
    directory starting with a '.' character will be ignored.

      $ cap deploy:upload FILES=templates,controller.rb".cleanup

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

  desc "DOC: Rolls back to a previous version and restarts. This is handy
    if you ever discover that you've deployed a lemon; 'cap rollback'
    and you're right back where you were, on the previously deployed
    version.".cleanup

  remote_task :rollback do
    if releases.length < 2
      abort "could not rollback the code because there is no prior release"
    else
      run "rm #{current_path}; ln -s #{previous_release} #{current_path} && rm -rf #{current_release}"
    end

    restart
  end

  desc "DOC: Clean up old releases. By default, the last 5 releases are
    kept on each server (though you can change this with the
    keep_releases variable). All other deployed revisions are removed
    from the servers. By default, this will use sudo to clean up the
    old releases, but if sudo is not available for your environment,
    set the :use_sudo variable to false instead.".cleanup

  remote_task :cleanup do
    count = fetch(:keep_releases, 5).to_i
    if count >= releases.length
      logger.important "no old releases to clean up"
    else
      logger.info "keeping #{count} of #{releases.length} deployed releases"

      directories = (releases - releases.last(count)).map { |release|
        File.join(releases_path, release) }.join(" ")

      invoke_command "rm -rf #{directories}", :via => run_method
    end
  end

end # namespace vlad

############################################################

  # set :scm, :subversion
  # set :deploy_via, :checkout

  # set(:revision)  { source.head }

  # set(:source)            { Capistrano::Deploy::SCM.new(scm, self) }
  # set(:real_revision) { source.local.query_revision(revision) { |cmd| with_env("LC_ALL", "C") { '#{cmd}' } } }

  # set(:strategery) { Capistrano::Deploy::Strategery.new(deploy_via, self) }

  # set(:previous_release)  { File.join(releases_path, releases[-2]) }

  # set(:current_revision)  { capture("cat #{current_path}/REVISION").chomp }
  # set(:latest_revision)   { capture("cat #{current_release}/REVISION").chomp }
  # set(:previous_revision) { capture("cat #{previous_release}/REVISION").chomp }

  # set(:run_method)        { fetch(:use_sudo, true) ? :sudo : :run }

############################################################

#   namespace :web do
#     desc <<-DESC
#       Present a maintenance page to visitors. Disables your application's web
#       interface by writing a "maintenance.html" file to each web server. The
#       servers must be configured to detect the presence of this file, and if
#       it is present, always display it instead of performing the request.

#       By default, the maintenance page will just say the site is down for
#       "maintenance", and will be back "shortly", but you can customize the
#       page by specifying the REASON and UNTIL environment variables:

#         $ cap deploy:web:disable
#               REASON="hardware upgrade"
#               UNTIL="12pm Central Time"

#       Further customization will require that you write your own task.
#     DESC
#     task :disable, :roles => :web, :except => { :no_release => true } do
#       require 'erb'
#       on_rollback { run "rm #{shared_path}/system/maintenance.html" }

#       reason = ENV['REASON']
#       deadline = ENV['UNTIL']

#       template = File.read(File.join(File.dirname(__FILE__), "templates", "maintenance.rhtml"))
#       result = ERB.new(template).result(binding)

#       put result, "#{shared_path}/system/maintenance.html", :mode => 0644
#     end

#     desc <<-DESC
#       Makes the application web-accessible again. Removes the
#       "maintenance.html" page generated by deploy:web:disable, which (if your
#       web servers are configured correctly) will make your application
#       web-accessible again.
#     DESC
#     task :enable, :roles => :web, :except => { :no_release => true } do
#       run "rm #{shared_path}/system/maintenance.html"
#     end
#   end
# end

