require 'test/vlad_test_case'
require 'vlad'
require 'vlad/git'

class TestVladGit < VladTestCase
  def setup
    super
    @scm = Vlad::Git.new
    set :repository, "git@myhost:/home/john/project1"
  end

  def test_checkout
    # Checkout to the current directory (which is what the :update task passes)
    cmd = @scm.checkout 'master', '.'
    assert_equal 'rm -rf repo && git clone git@myhost:/home/john/project1 repo && cd repo && git checkout -f -b deployed-master master', cmd

    # Mimic :update task
    # 'head' should become HEAD
    cmd = @scm.checkout 'head', '.'
    assert_equal 'rm -rf repo && git clone git@myhost:/home/john/project1 repo && cd repo && git checkout -f -b deployed-HEAD HEAD', cmd

    # Checkout to a relative path
    cmd = @scm.checkout 'master', 'some/relative/path'
    assert_equal 'rm -rf some/relative/path && git clone git@myhost:/home/john/project1 some/relative/path && cd some/relative/path && git checkout -f -b deployed-master master', cmd
  end

  def test_export
    cmd = @scm.export 'master', 'the/release/path'
    assert_equal 'mkdir -p the/release/path && git archive --format=tar master | (cd the/release/path && tar xf -)', cmd
  end

  def test_revision
    ['head', 'HEAD'].each do |head|
      cmd = @scm.revision(head)
      expected = "`git rev-parse HEAD`"
      assert_equal expected, cmd
    end
  end
end
