class Vlad::Perforce

  def update(revision)
    "p4 sync ...#{rev_no(revision)}"
  end

  ##
  # Returns the p4 command that will checkout +revision+ into the directory
  # +destination+.

  def checkout(revision, destination)
    "cd #{repository} && p4 sync ...#{rev_no(revision)} && cp -rp . #{destination}"
  end

  ##
  # Returns the p4 command that will export +revision+ into the directory
  # +directory+.

  alias :export :checkout

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a Perforce revision specification.

  def revision(revision)
    "`p4 changes -s submitted -m 1 ...#{rev_no(revision)} | cut -f 2 -d\\ `"
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
