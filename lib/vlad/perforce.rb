class Vlad::Perforce

  set :p4_cmd, "p4"
  set :source, Vlad::Perforce.new

  ##
  # Returns the p4 command that will checkout +revision+ into the directory
  # +destination+.

  def checkout(revision, destination)
    "#{p4_cmd} sync ...#{rev_no(revision)}"
  end

  ##
  # Returns the p4 command that will export +revision+ into the directory
  # +directory+.

  def export(revision_or_source, destination)
    if revision_or_source =~ /^(\d+|head)$/i then
      "(cd #{destination} && #{p4_cmd} sync ...#{rev_no(revision_or_source)})"
    else
      "cp -r #{revision_or_source} #{destination}"
    end
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a Perforce revision specification.

  def revision(revision)
    "`#{p4_cmd} changes -s submitted -m 1 ...#{rev_no(revision)} | cut -f 2 -d\\ `"
  end

  ##
  # Maps revision +revision+ into a Perforce revision.

  def rev_no(revision)
    case revision.to_s
    when /head/i then
      "#head"
    when /^\d+$/ then
      "@#{revision}"
    else
      revision
    end
  end
end

namespace :vlad do
  remote_task :setup_app, :roles => :app do
    p4data = p4port = p4user = p4passwd = nil

    if ENV['P4CONFIG'] then
      p4config_name = ENV['P4CONFIG']
      p4config = nil
      orig_dir = Dir.pwd.split File::SEPARATOR

      until orig_dir.length == 1 do
        p4config = orig_dir + [p4config_name]
        p4config = File.join p4config
        break if File.exist? p4config
        orig_dir.pop
      end

      raise "couldn't find .p4config" unless File.exist? p4config

      p4data = File.readlines(p4config).map { |line| line.strip.split '=', 2 }
      p4data = Hash[*p4data.flatten]
    else
      p4data = ENV
    end

    p4port = p4data['P4PORT']
    p4user = p4data['P4USER']
    p4passwd = p4data['P4PASSWD']

    raise "couldn't get P4PORT" if p4port.nil?
    raise "couldn't get P4USER" if p4user.nil?
    raise "couldn't get P4PASSWD" if p4passwd.nil?

    p4client = [p4user, target_host, application].join '-'

    require 'tmpdir'
    require 'tempfile'

    put File.join(scm_path, '.p4config'), 'vlad.p4config' do
      [ "P4PORT=#{p4port}",
        "P4USER=#{p4user}",
        "P4PASSWD=#{p4passwd}",
        "P4CLIENT=#{p4client}" ].join("\n")
    end

    p4client_path = File.join deploy_to, 'p4client.tmp'

    put p4client_path, 'vlad.p4client' do
      conf = <<-"CLIENT"
Client:	#{p4client}

Owner:	#{p4user}

Root:	#{scm_path}

View:
  #{repository}/... //#{p4client}/...
      CLIENT
    end

    cmds = [
      "cd #{scm_path}",
      "p4 client -i < #{p4client_path}",
      "rm #{p4client_path}",
    ]

    run cmds.join(' && ')
  end
end

