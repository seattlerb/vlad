require 'vlad/scm'

##
# Implements Vlad::SCM interface for the Perforce revision control system
# http://www.perforce.com.

class Vlad::Perforce < Vlad::SCM

  def initialize # :nodoc:
    @command = 'p4'
    @head = 'head'
  end

  ##
  # Returns the p4 command that will checkout +revision+ into the directory
  # +destination+.

  def checkout(revision, destination)
    cmd = "cd #{repository} && "
    cmd << command(:sync, "...#{rev_no(revision)}")
    cmd << " && cp -rp . #{destination}"
  end

  ##
  # Returns the p4 command that will export +revision+ into the directory
  # +directory+.

  alias :export :checkout

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a Perforce revision specification.

  def revision(revision)
    cmd = command :changes, "-s submitted -m 1 ...#{rev_no(revision)} | cut -f 2 -d\\ "
    "`#{cmd}`"
  end

  ##
  # Maps revision +revision+ into a Perforce revision.

  def rev_no(revision)
    case revision.to_s
    when @head then
      "#head"
    when /^\d+/ then
      "@#{revision}"
    else
      revision
    end
  end
end

