require './test_common.rb'

class TestEddies < Test::Unit::TestCase
  def test_binary_join
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    e = Crocus::PushEddy.new([r,s], [[[r, [0]], [s, [1]]]]) do |i|
      outs << i.flatten
    end
    r.insert([1,:a])
    s.insert([:b,1])
    r.insert([2,:c])
    s.insert([:d,2])
    r.flush; s.flush; e.flush
    assert_equal([[1, :a, :b, 1],[2, :c, :d, 2]], outs.sort)      
  end
  
  def test_unary
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    e = Crocus::PushEddy.new([r], []) do |i|
      outs << i.flatten
    end
    r.insert([1,:a])
    r.flush; e.flush
    assert_equal([[1, :a]], outs)      
  end  
   
  def test_self_join
    outs = []
    r1 = Crocus::PushElement.new("r1", 2, [0])
    r2 = Crocus::PushElement.new("r2", 2, [0])
    r = Crocus::PushElement.new("r", 2, [0]) do |i|
      r1 << i
      r2 << i
    end
    e = Crocus::PushEddy.new([r1,r2], [[[r1, [0]], [r2, [0]]]]) do |i|
      outs << i.flatten
    end
    r.insert([1,:a])
    r.insert([2,:b])
    r.flush; r1.flush; r2.flush; e.flush
    assert_equal([[1, :a, 1, :a], [2, :b, 2, :b]], outs.sort)
  end
  
  def test_cross_product
    count = 0
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    e = Crocus::PushEddy.new([r,s], []) do |i|
      outs << i.flatten
    end
    r.insert([1,:a])
    s.insert([1,:b])
    s.insert([2,:c])
    r.insert([3,:d])
    r.flush; s.flush; e.flush
    assert_equal([[1, :a, 1, :b], [1, :a, 2, :c], [3, :d, 1, :b], [3, :d, 2, :c]], outs.sort)
  end
  
  def test_ternary_join
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    t = Crocus::PushElement.new('t', 2, [])
    e = Crocus::PushEddy.new([r,s,t], [[[r, [0]], [s, [0]]], [[s, [0]], [t, [0]]]]) do |i|
      outs << i.flatten
    end
    r.insert([1,:a])
    s.insert([1,:b])
    t.insert([1,:c])
    r.insert([2,:a])
    s.insert([2,:b])
    t.insert([2,:c])
    r.flush; s.flush; t.flush; e.flush
    assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
  end
  
  def test_multiple_join_preds
  end
  
  def test_selection_preds
  end
  
  def test_multicolumn_keys
  end
end
    