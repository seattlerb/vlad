class Vlad::Darcs

  set :source, Vlad::Darcs.new
  set :darcs_cmd, "darcs"

  ##
  # Ignores +revision+ for now, exports into directory +destination+

  def checkout(revision, destination)
    [ %{(test ! -d #{destination}/_darcs && #{darcs_cmd} init "--repodir=#{destination}") || true},
      %{#{darcs_cmd} pull -a "--repodir=#{destination}" #{repository}},
    ].join(" && ")
  end

  def export(dir, dest)
    [ %{mkdir -p #{dest}},
      %{ls | grep ^[^_] | xargs -I vlad cp -R vlad #{dest}}
    ].join(" && ")
  end

  def revision(revision)
    revision
  end
end
