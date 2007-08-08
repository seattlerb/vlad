require 'vlad/scm'

# Implements the Capistrano SCM interface for the Perforce revision
# control system (http://www.perforce.com).
class Vlad::Perforce < Vlad::SCM
  def initialize
    @command = 'p4'
    @head = 'head'
  end

  # Returns the command that will sync the given revision to the given
  # destination directory. The perforce client has a fixed destination so
  # the files must be copied from there to their intended resting place.
  def checkout(revision, destination)
    p4_command(revision, destination)
  end

  # Returns the command that will sync the given revision to the given
  # destination directory. The perforce client has a fixed destination so
  # the files must be copied from there to their intended resting place.
  def export(revision, destination)
    p4_command(revision, destination)
  end

  # Returns the command that will sync the given revision to the given
  # destination directory with specific options. The perforce client has 
  # a fixed destination so the files must be copied from there to their 
  # intended resting place.          
  def p4_command(revision, destination)
    cmd = "cd #{fetch(:repository)} && " 
    cmd << command(:sync, "...#{rev_no(revision)}")
    cmd << " && cp -rp . #{destination}" 
  end

  def real_revision(revision)
    command :changes, "-s submitted -m 1 ...#{rev_no(revision)} | cut -f 2 -d\\ " 
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
end

