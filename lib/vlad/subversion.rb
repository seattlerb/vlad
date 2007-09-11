class Vlad::Subversion

  set :source, Vlad::Subversion.new
  set :svn_cmd, "svn"

  ##
  # Returns the command that will check out +revision+ from the repository
  # into directory +destination+

  def checkout(revision, destination)
    "#{svn_cmd} co -r #{revision} #{repository} #{destination}"
  end

  ##
  # Returns the command that will export +revision+ from the repository into
  # the directory +destination+.

  def export(revision_or_source, destination)
    if revision_or_source =~ /^(\d+|head)$/i then
      "#{svn_cmd} export -r #{revision_or_source} #{repository} #{destination}"
    else
      "#{svn_cmd} export #{revision_or_source} #{destination}"
    end
  end

  ##
  # Returns a command that maps human-friendly revision identifier +revision+
  # into a subversion revision specification.

  def revision(revision)
    "`#{svn_cmd} info #{repository} | grep 'Revision:' | cut -f2 -d\\ `"
  end
end

