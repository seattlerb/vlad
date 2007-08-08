# The ancestor class for all Capistrano SCM implementations. It provides
# minimal infrastructure for subclasses to build upon and override.
#
# Note that subclasses that implement this abstract class only return
# the commands that need to be executed--they do not execute the commands
# themselves. In this way, the deployment method may execute the commands
# either locally or remotely, as necessary.
class Vlad::SCM
  # Checkout a copy of the repository, at the given +revision+, to the
  # given +destination+. The checkout is suitable for doing development
  # work in, e.g. allowing subsequent commits and updates.
  def checkout(revision, destination)
    raise NotImplementedError, "`checkout' is not implemented by #{self.class.name}"
  end

  def export(revision, destination)
    raise NotImplementedError, "`export' is not implemented by #{self.class.name}"
  end

  # If the given revision represents a "real" revision, this should
  # simply return the revision value. If it represends a pseudo-revision
  # (like Subversions "HEAD" identifier), it should yield a string
  # containing the commands that, when executed will return a string
  # that this method can then extract the real revision from.
  def revision(revision)
    raise NotImplementedError, "'revision' is not implemented by #{self.class.name}"
  end

  # A helper method that can be used to define SCM commands naturally.
  # It returns a single string with all arguments joined by spaces,
  # with the scm command prefixed onto it.
  def command(*args)
    [@command, *args].compact.join(" ")
  end

  def fetch(var)
    Vlad.instance.fetch(var)
  end
end

