require 'vlad'

namespace :vlad do
  namespace :maintenance do
    remote_task :on, :roles => [:web] do
      run "cp -f #{shared_path}/config/maintenance.html #{shared_path}/system/"
    end

    remote_task :off, :roles => [:web] do
      run "rm -f #{shared_path}/system/maintenance.html"
    end
  end
end
