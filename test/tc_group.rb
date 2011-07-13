require './test_common.rb'

class TestGroupBy < Test::Unit::TestCase
  def test_group_by
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushGroup.new('g', 2, [r], [1], [[Crocus::Sum.new, 0]]) do |i|
      outs << i.flatten unless i.nil?
    end
    r.set_block {|i| g.insert(i)}
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    r.flush; g.flush
    assert_equal([[:a, 3],[:c, 2]], outs.sort)      
  end
  
  def test_argagg
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    g = Crocus::PushArgAgg.new('g', 2, [r], [1], [[Crocus::Min.new, 0]]) do |i|
      outs << i.flatten unless i.nil?
    end
    r.set_block {|i| g.insert(i)}
    r.insert([1,:a])
    r.insert([2,:a])
    r.insert([2,:c])
    r.flush; g.flush
    assert_equal([[1, :a],[2, :c]], outs.sort)      
  end
end