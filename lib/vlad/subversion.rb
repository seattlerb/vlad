require 'vlad/scm'

##
# Implements Vlad::SCM interface for the Perforce revision control system
# http://www.perforce.com.

class Vlad::Subversion < Vlad::SCM

  def initialize # :nodoc:
    @command = 'svn'
    @head = 'HEAD'
  end

  ##
  # Returns the command that will check out +revision+ from the repository
  # into directory +destination+

  def checkout(revision, destination)
    command :co, "-r #{revision}", fetch(:repository), destination
  end

  ##
  # Returns the command that will export +revision+ from the repository into
  # the directory +destination+.

  def export(revision, destination)
    command :export, "-r #{revision}", fetch(:repository), destination
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a subversion revision specification.

  def revision(revision)
    cmd = command :info, "#{fetch(:repository)} | grep 'Revision:' | cut -f2 -d\\ "
    "`#{cmd}`"
  end

end
