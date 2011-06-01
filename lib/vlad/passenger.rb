require 'vlad'

namespace :vlad do
  desc 'Restart Passenger'
  remote_task :start_app, :roles => :app do
    run "touch #{latest_release}/tmp/restart.txt"
  end
end
