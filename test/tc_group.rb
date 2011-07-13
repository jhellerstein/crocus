require './test_common.rb'

class TestGroupBy < Test::Unit::TestCase
  def test_group_by
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushGroup.new('g', 2, [r], [1], [[Crocus::Sum.new, 0]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(g)
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    r.flush; g.end
    assert_equal([[:a, 3],[:c, 2]], outs.sort)      
  end
  
  def test_agg_nogroup
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushGroup.new('g', 1, [r], nil, [[Crocus::Sum.new, 0]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(g)
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    r.flush; g.end
    assert_equal([[5]], outs.sort)
  end
      
  def test_argagg
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushArgAgg.new('g', 2, [r], [1], [[Crocus::Min.new, 0]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(g)
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    g.end
    assert_equal([[1, :a],[2, :c]], outs.sort)      
  end
  
  def test_argagg_nogroup
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushArgAgg.new('g', 2, [r], nil, [[Crocus::Min.new, 0]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(g)
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    g.end
    assert_equal([[1, :a]], outs.sort)      
  end
end