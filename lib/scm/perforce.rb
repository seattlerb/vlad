# Implements the Capistrano SCM interface for the Perforce revision
# control system (http://www.perforce.com).
class Vlad::SCM::Perforce < Vlad::SCM
  # Perforce understands '#head' to refer to the latest revision in the
  # depot.
  def head
    'head'
  end

  # Returns the command that will sync the given revision to the given
  # destination directory. The perforce client has a fixed destination so
  # the files must be copied from there to their intended resting place.
  def checkout(revision, destination)
    p4_sync(revision, destination, "-f")
  end

  # Returns the command that will sync the given revision to the given
  # destination directory. The perforce client has a fixed destination so
  # the files must be copied from there to their intended resting place.
  def sync(revision, destination)
    p4_sync(revision, destination, "-f")
  end

  # Returns the command that will sync the given revision to the given
  # destination directory. The perforce client has a fixed destination so
  # the files must be copied from there to their intended resting place.
  def export(revision, destination)
    p4_sync(revision, destination, "-f")
  end

  # Returns the command that will do an "p4 diff2" for the two revisions.
  def diff(from, to=head)
    scm authentication, :diff2, "-u -db", "//#{p4client}/...#{rev_no(from)}", "//#{p4client}/...#{rev_no(to)}"
  end

  # Returns a "p4 changes" command for the two revisions.
  def log(from=1, to=head)
    scm authentication, :changes, "-s submitted", "//#{p4client}/...#{rev_no(from)},#(rev_no(to)}"
  end

  def query_revision(revision)
    return revision if revision.to_s =~ /^\d+$/
    command = scm(authentication, :changes, "-s submitted", "-m 1", "//#{p4client}/...#{rev_no(revision)}")
    yield(command)[/Change (\d+) on/, 1]
  end

  def rev_no(revision)                     
    case revision.to_s
    when "head"
      "#head"
    when /^\d+/  
      "@#{revision}"
    else
      revision
    end          
  end

  # Builds the set of authentication switches that perforce understands.
  def authentication
    [ p4port   && "-p #{p4port}",
      p4user   && "-u #{p4user}",
      p4passwd && "-P #{p4passwd}",
      p4client && "-c #{p4client}" ].compact.join(" ")
  end

  # Returns the command that will sync the given revision to the given
  # destination directory with specific options. The perforce client has 
  # a fixed destination so the files must be copied from there to their 
  # intended resting place.          
  def p4_sync(revision, destination, options="")
    p4client_root = "`#{command} #{authentication} client -o | grep ^Root | cut -f2`"
    scm authentication, :sync, options, "#{rev_no(revision)}", "&& cp -rf #{p4client_root} #{destination}"          
  end

  def p4client
    variable(:p4client)
  end

  def p4port
    variable(:p4port)
  end

  def p4user
    variable(:p4user) || variable(:scm_username)
  end

  def p4passwd
    variable(:p4passwd) || variable(:scm_password)
  end
end

