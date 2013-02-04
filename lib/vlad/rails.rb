namespace :vlad do
  set :rails_env,      "production"
  set :rails_env_var,  "RAILS_ENV"
  set :migrate_args,   ""
  set :migrate_target, :latest
  set :mkdirs,         %w(tmp db)
  set :shared_paths, {
    'log'    => 'log',
    'system' => 'public/system',
    'pids'   => 'tmp/pids',
  }

  desc "Run the migrate rake task for the the app. By default this is run in
    the latest app directory.  You can run migrations for the current app
    directory by setting :migrate_target to :current.  Additional environment
    variables can be passed to rake via the migrate_args variable.".cleanup

  # No application files are on the DB machine, also migrations should only be
  # run once.
  remote_task :migrate, :roles => :app do
    next unless target_host == Rake::RemoteTask.hosts_for(:app).first

    directory = case migrate_target.to_sym
                when :current then current_path
                when :latest  then latest_release
                else
                  raise(ArgumentError,
                        "unknown migration target #{migrate_target.inspect}")
                end

    run ["cd #{directory}",
         "#{rake_cmd} #{rails_env_var}=#{rails_env} db:migrate #{migrate_args}"
        ].join(" && ")
  end
end
