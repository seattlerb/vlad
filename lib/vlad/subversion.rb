require 'vlad/scm'

# Implements the Capistrano SCM interface for the Subversion revision
# control system (http://subversion.tigris.org).
class Vlad::Subversion < Vlad::SCM
  # Subversion understands 'HEAD' to refer to the latest revision in the
  # repository.
  def initialize
    @command = 'svn'
    @head = 'HEAD'
  end

  # Returns the command that will check out the given revision to the
  # given destination.
  def checkout(revision, destination)
    command :co, "-r #{revision}", fetch(:repository), destination
  end

  # Returns the command that will do an "svn export" of the given revision
  # to the given destination.
  def export(revision, destination)
    command :export, "-r #{revision}", fetch(:repository), destination
  end

  # Attempts to translate the given revision identifier to a "real"
  # revision. If the identifier is an integer, it will simply be returned.
  # Otherwise, this will yield a string of the commands it needs to be
  # executed (svn info), and will extract the revision from the response.
  def real_revision(revision)
    command :info, "#{fetch(:repository)} | grep 'Revision:' | cut -f2 -d\\ "
  end
end
