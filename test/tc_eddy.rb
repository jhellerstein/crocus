require './test_common.rb'

class TestEddies < Test::Unit::TestCase
  # baseline: an eddy on only one source
  def test_unary
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    e = Crocus::PushEddy.new('e1', 2, [r], []) do |i|
      outs << i
    end
    r.wire_to(e)
    r.insert([1,:a])
    r.end
    assert_equal([[1, :a]], outs)      
  end  
   
  # simple symmetric hash join
  def test_binary_join
     outs = []
     r = Crocus::PushElement.new('r', 2, [])
     s = Crocus::PushElement.new('s', 2, [])
     e = Crocus::PushEddy.new('e1', 4, [r,s], [[[r, [0]], [s, [1]]]]) do |i|
       outs << i
     end
     r.wire_to(e)
     s.wire_to(e)
     r.insert([1,:a])
     s.insert([:b,1])
     r.insert([2,:c])
     s.insert([:d,2])
     r.end; s.end
     assert_equal([[1, :a, :b, 1],[2, :c, :d, 2]], outs.sort)      
   end
   
   # here's the pattern for self-join
   # XXX maybe differentiate (name,instance) of input elements rather than requiring differently-named elements?
   def test_self_join
     outs = []
     r = Crocus::PushElement.new("r", 2, [])
     r1 = Crocus::PushElement.new("r1", 2, [r])
     r2 = Crocus::PushElement.new("r2", 2, [r])
     e = Crocus::PushEddy.new('e1', 4, [r1,r2], [[[r1, [0]], [r2, [0]]]]) do |i|
       outs << i
     end
     r.wire_to(r1)
     r.wire_to(r2)
     r1.wire_to(e)
     r2.wire_to(e)
     r.insert([1,:a])
     r.insert([2,:b])
     r.end
     assert_equal([[1, :a, 1, :a], [2, :b, 2, :b]], outs.sort)
   end
   
   # simple binary cartesian products
   def test_cross_product
     count = 0
     outs = []
     r = Crocus::PushElement.new('r', 2, [])
     s = Crocus::PushElement.new('s', 2, [])
     e = Crocus::PushEddy.new('e1', 4, [r,s], []) do |i|
       outs << i
     end
     r.wire_to(e)
     s.wire_to(e)
     r.insert([1,:a])
     s.insert([1,:b])
     s.insert([2,:c])
     r.insert([3,:d])
     r.end; s.end
     assert_equal([[1, :a, 1, :b], [1, :a, 2, :c], [3, :d, 1, :b], [3, :d, 2, :c]], outs.sort)
   end
  
  # simple 3-way equijoin (r*s*t) with potential cartesian product between r and t
  def test_ternary_join
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    t = Crocus::PushElement.new('t', 2, [])
    e = Crocus::PushEddy.new('e1', 6, [r,s,t], [[[r, [0]], [s, [0]]], [[s, [0]], [t, [0]]]]) do |i|
      outs << i
    end
    r.wire_to(e)
    s.wire_to(e)
    t.wire_to(e)
    r.insert([1,:a])
    s.insert([1,:b])
    t.insert([1,:c])
    r.insert([2,:a])
    s.insert([2,:b])
    t.insert([2,:c])
    r.end; s.end; t.end
    assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
  end
  
  # join predicates with multiple matching columns
  def test_multicolumn_join_preds
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    e = Crocus::PushEddy.new('e', 4, [r,s], [[[r, [0,1]], [s, [1,0]]]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(e)
    s.wire_to(e)
    r.insert([1,:a])
    s.insert([:a,1])
    r.insert([2,:b])
    s.insert([:b,2])
    s.insert([:c,2])
    r.insert([2,:d])
    r.end; s.end
    assert_equal([[1, :a, :a, 1],[2, :b, :b, 2]], outs.sort)
  end
  
  # multiple independent preds on the same pair of tables.  same semantics
  # as previous. 
  # XXX would be nice if engine optimized to the previous
  def test_multiple_join_preds
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    e = Crocus::PushEddy.new('e', 4, [r,s], [[[r, [0]], [s, [1]]], [[r,[1]], [s,[0]]]]) do |i|
      outs << i unless i.nil?
    end
    r.wire_to(e)
    s.wire_to(e)
    r.insert([1,:a])
    s.insert([:a,1])
    r.insert([2,:b])
    s.insert([:b,2])
    s.insert([:c,2])
    r.insert([2,:d])
    r.end; s.end
    assert_equal([[1, :a, :a, 1],[2, :b, :b, 2]], outs.sort)
  end
  
  # cyclic join preds, which require multiple stems on the same source
  def test_cyclic_query
    outs = []
    r = Crocus::PushElement.new('r', 2, [])
    s = Crocus::PushElement.new('s', 2, [])
    t = Crocus::PushElement.new('t', 2, [])
    e = Crocus::PushEddy.new('e', 6, [r,s,t], [[[r, [0]], [s, [0]]], [[s, [0]], [t, [0]]], [[t,[0]], [r, [0]]]]) do |i|
      outs << i
    end
    r.wire_to(e)
    s.wire_to(e)
    t.wire_to(e)
    r.insert([1,:a])
    s.insert([1,:b])
    t.insert([1,:c])
    r.insert([2,:a])
    s.insert([2,:b])
    t.insert([2,:c])
    r.end; s.end; t.end
    assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
  end  
  
  require 'set'
  def test_eddy_recursion
    outs = Set.new
    links = Set.new
    link = Crocus::PushElement.new('link', 2, [])
    path = Crocus::PushElement.new('path', 2, [])
    j = Crocus::PushEddy.new('e', 2, [link,path], [[[link,[1]],[path,[0]]]]) do |i|
      tup = [i[0], i[3]]
      unless outs.include? tup
        outs << tup
        path << tup
      end
    end
    link.wire_to(j)
    path.wire_to(j)
    links << ([1,2])
    links << ([2,3])
    links << ([3,4])
    links << ([6,7])
    links << ([2,7])
    links.each {|l| link << l; path << l}
    link.end; path.end
    assert_equal([[1,2],[1,3],[1,4],[1,7],[2,3],[2,4],[2,7],[3,4],[6,7]], (outs+links).to_a.sort)
  end  
end
    