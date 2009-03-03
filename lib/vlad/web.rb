require 'vlad'

namespace :vlad do
  namespace :web do
    remote_task :enable, :roles => [:web] do
      run "if [ -f #{shared_path}/system/maintenance.html ]; then rm -f #{shared_path}/system/maintenance.html; fi"
    end
    remote_task :disable, :roles => [:web] do
      run "cp -f #{shared_path}/config/maintenance.html #{shared_path}/system/"
    end
  end
end
