##
# Abstract class for defining Vlad SCM plugins.
#
# To define a new SCM plugin you need to set the command type in initiaize and
# define the appropriate methods.  See Vlad::Subversion or Vlad::Perforce for
# examples.
#
# Significant portions of Vlad::SCM, Vlad::Subversion and Vlad::Perforce were
# borrowed from Capistrano.

class Vlad::SCM

  ##
  # Sets the SCM command name.

  def initialize
    @command = nil
  end

  ##
  # Returns the command that will checkout +revision+ from the repository into
  # the directory +destination+.

  def checkout(revision, destination)
    raise NotImplementedError, "`checkout' is not implemented by #{self.class.name}"
  end

  ##
  # Returns the command that will export +revision+ from the repository into
  # the directory +destination+.

  def export(revision, destination)
    raise NotImplementedError, "`export' is not implemented by #{self.class.name}"
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a SCM revision specification.

  def revision(revision)
    raise NotImplementedError, "'revision' is not implemented by #{self.class.name}"
  end

  ##
  # Builds an SCM command from the defined command name and +args+.

  def command(*args)
    [@command, *args].compact.join(" ")
  end

  ##
  # Retrieves environment variable +var+ from the vlad configuration.

  def fetch(var)
    Rake::RemoteTask.fetch(var)
  end

end

