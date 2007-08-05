require 'test/unit'
require 'vlad'

class TestVlad < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
    @vlad.reset
  end

  def test_set
    @vlad.set :foo, 5
    assert_equal 5, @vlad.foo
  end

  def test_set_with_block
    x = 1
    @vlad.set(:foo) { x += 2 }

    assert_equal 3, @vlad.foo
    assert_equal 3, @vlad.foo
  end

  def test_set_with_nil
    @vlad.set(:foo, nil)
    assert_equal nil, @vlad.foo
  end
end

