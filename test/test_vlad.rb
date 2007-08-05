require 'test/unit'
class TestVladSet < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
  end

  def test_set
    @vlad.set :foo, 5
  end
end

