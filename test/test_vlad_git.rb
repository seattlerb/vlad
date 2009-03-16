require 'test/vlad_test_case'
require 'vlad'
require 'vlad/git'

class TestVladGit < VladTestCase
  def setup
    super
    @scm = Vlad::Git.new
    set :repository, "git@myhost:/home/john/project1"
    #set :scm_path, "/the/scm/path"
  end

  # Checkout the way the default :update task invokes the method
  def test_checkout
    cmd = @scm.checkout 'head', '/the/scm/path'
    assert_equal 'rm -rf /the/scm/path/repo && git clone git@myhost:/home/john/project1 /the/scm/path/repo && cd /the/scm/path/repo && git checkout -f -b deployed-HEAD HEAD && cd -', cmd
  end

  # This is not how the :update task invokes the method
  def test_checkout_revision
    # Checkout to the current directory
    cmd = @scm.checkout 'master', '.'
    assert_equal 'rm -rf ./repo && git clone git@myhost:/home/john/project1 ./repo && cd ./repo && git checkout -f -b deployed-master master && cd -', cmd

    # Checkout to a relative path
    cmd = @scm.checkout 'master', 'some/relative/path'
    assert_equal 'rm -rf some/relative/path/repo && git clone git@myhost:/home/john/project1 some/relative/path/repo && cd some/relative/path/repo && git checkout -f -b deployed-master master && cd -', cmd
  end

  def test_export
    cmd = @scm.export 'master', 'the/release/path'
    assert_equal 'mkdir -p the/release/path && cd repo && git archive --format=tar deployed-master | (cd the/release/path && tar xf -) && cd - && cd ..', cmd
  end

  def test_revision
    ['head', 'HEAD'].each do |head|
      cmd = @scm.revision(head)
      expected = "`git rev-parse HEAD`"
      assert_equal expected, cmd
    end
  end
end
