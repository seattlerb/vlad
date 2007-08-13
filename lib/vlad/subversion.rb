class Vlad::Subversion

  def update(revision)
    "svn update -r #{revision} #{repository}}"
  end

  ##
  # Returns the command that will check out +revision+ from the repository
  # into directory +destination+

  def checkout(revision, destination)
    "svn co -r #{revision} #{repository} #{destination}"
  end

  ##
  # Returns the command that will export +revision+ from the repository into
  # the directory +destination+.

  def export(revision_or_source, destination)
    if revision_or_source =~ /^(\d+|head)$/i then
      "svn export -r #{revision_or_source} #{repository} #{destination}"
    else
      "svn export #{revision_or_source} #{destination}"
    end
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a subversion revision specification.

  def revision(revision)
    "`svn info #{repository} | grep 'Revision:' | cut -f2 -d\\ `"
  end
end
