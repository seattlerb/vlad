require 'vlad'

namespace :vlad do

  set :lighttpd_port, 65536
  set :web_command, "lighttpd"
  set :lighttpd_user, "nobody"
  set :lighttpd_group, "nobody"
  set(:lighttpd_init) { "#{shared_path}/lighttpd.sh" }
  set(:lighttpd_conf) { "#{shared_path}/lighttpd.conf" }

  desc "Prepares application servers for deployment. Lighttpd
configuration is set via the lighttpd_* variables.".cleanup

  remote_task :setup_lighttpd, :roles => :app do
    require 'tempfile'

    put lighttpd_conf, 'vlad.lighttpd_config' do
      conf = <<-"EOF"
server.modules = ( "mod_rewrite",
                   "mod_access",
                   "mod_fastcgi",
                   "mod_compress",
                   "mod_accesslog" )

server.document-root     = "#{current_path}/public"
server.errorlog          = "#{shared_path}/log/lighttpd.error.log"
accesslog.filename       = "#{shared_path}/log/lighttpd.access.log"
server.pid-file          = "#{shared_path}/pids/lighttpd.pid"
server.port              =  #{lighttpd_port}
server.username          = "#{lighttpd_user}"
server.groupname         = "#{lighttpd_group}"
server.error-handler-404 = "/dispatch.fcgi"
server.indexfiles        = ( "index.html", "index.rb" )
url.access-deny          = ( "~", ".inc" )
compress.cache-dir       = "#{shared_path}/tmp/cache/compress"
compress.filetype        = ("text/html","text/plain","text/javascript","text/css")
server.tag               = "lighttpd | TextDriven"

fastcgi.server = (
  ".fcgi" => (
    "localhost" => (
      "min-procs" => 1,
      "max-procs" => 1,
      "socket"    => "#{shared_path}/pids/rubyholic.socket",
      "bin-path"  => "#{current_path}/public/dispatch.fcgi",
      "bin-environment" => ( "RAILS_ENV" => "production" ) ) ) )
      EOF
    end

    run "mkdir -p \"#{shared_path}/tmp/cache/compress\""
  end

  desc "(Re)Start the web servers"

  remote_task :start_web, :roles => :web  do
    cmd = %w(lighttpd ruby).map {|app| "(killall #{app} || true)"}.join(" && ")
    cmd += " && #{web_command} -f #{lighttpd_conf} </dev/null >/dev/null 2>&1"
    run cmd
  end

  desc "Stop the web servers"
  remote_task :stop_web, :roles => :web  do
    cmd = %w(lighttpd ruby).map {|app| "(killall #{app} || true)"}.join(" && ")

    run cmd
  end

  ##
  # Everything HTTP.

  desc "(Re)Start the web and app servers"

  remote_task :start do
    Rake::Task['vlad:start_app'].invoke
    Rake::Task['vlad:start_web'].invoke
  end

  desc "Stop the web and app servers"

  remote_task :stop do
    Rake::Task['vlad:stop_app'].invoke
    Rake::Task['vlad:stop_web'].invoke
  end
end
