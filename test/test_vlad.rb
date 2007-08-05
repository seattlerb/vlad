require 'test/unit'
require 'vlad'

class TestVladSet < Test::Unit::TestCase
  def setup
    @vlad = Vlad.instance
  end

  def test_set
    @vlad.set :foo, 5
    assert_equal 5, @vlad.env[:foo]
  end

  def test_set_with_block
    x = 1
    @vlad.set :foo { x += 2 } 
    assert_equal 3, @vlad.env[:foo]
    assert_equal 3, @vlad.env[:foo]
  end 
  
  def test_set_with_dynamic_string
  end 

  def test_set_with_immediate_value
  end 
end

