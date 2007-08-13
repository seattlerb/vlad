class Vlad::Perforce

  def self.reset
    set :p4cmd, "p4"
    set :p4port, "localhost:1666"
    set(:p4user) { raise(Vlad::ConfigurationError,
                         "Please specify the name of the p4 user") }
    set(:p4pass) { raise(Vlad::ConfigurationError,
                         "Please specify the password of the p4 user") }
    set :p4client do "#{p4user}-#{application}"; end
  end

  reset

  ##
  # Returns the p4 command that will checkout +revision+ into the directory
  # +destination+.

  def checkout(revision, destination)
    "#{p4cmd} -p #{p4port} -u #{p4user} -P #{p4pass} -c #{p4client} sync ...#{rev_no(revision)}"
  end

  ##
  # Returns the p4 command that will export +revision+ into the directory
  # +directory+.

  def export(revision_or_source, destination)
    if revision_or_source =~ /^(\d+|head)$/i then
      "(cd #{destination} && #{p4cmd} -p #{p4port} -u #{p4user} -P #{p4pass} -c #{p4client} sync ...#{rev_no(revision_or_source)})"
    else
      "cp -r #{revision_or_source} #{destination}"
    end
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a Perforce revision specification.

  def revision(revision)
    "`#{p4cmd} -p #{p4port} -u #{p4user} -P #{p4pass} -c #{p4client} changes -s submitted -m 1 ...#{rev_no(revision)} | cut -f 2 -d\\ `"
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
