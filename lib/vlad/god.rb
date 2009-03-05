require 'vlad'

namespace :vlad do
  ## God module for merb app server

  desc "Prepares application servers for deployment.".cleanup

  remote_task :setup_app, :roles => :app do
    # do nothing?
  end

  desc "Restart the app servers"

  remote_task :start_app, :roles => :app do
    run "god restart #{cluster_name}"
  end

  desc "Stop the app servers"

  remote_task :stop_app, :roles => :app do
    run "god stop #{cluster_name}"
  end
end
