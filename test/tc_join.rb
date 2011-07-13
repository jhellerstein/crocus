require './test_common.rb'

class TestJoins < Test::Unit::TestCase
  def test_ShJoin
     outs = []
     r = Crocus::PushElement.new('r', 2, [])
     s = Crocus::PushElement.new('s', 2, [])
     j = Crocus::ShJoin.new('j', [r,s], [[0],[1]]) do |i|
       outs << i.flatten
     end
     r.set_block {|i| j.insert(i,r)}
     s.set_block {|i| j.insert(i,s)}
     r.insert([1,:a])
     s.insert([:b,1])
     r.insert([2,:c])
     s.insert([:d,2])
     r.flush; s.flush; j.flush
     assert_equal([[1, :a, :b, 1],[2, :c, :d, 2]], outs.sort)      
   end
   
   def test_two_joins
     outs = []
     r = Crocus::PushElement.new('r', 2, [])
     s = Crocus::PushElement.new('s', 2, [])
     t = Crocus::PushElement.new('t', 2, [])
     j1 = Crocus::ShJoin.new('j1', [r,s], [[0],[0]])
     j2 = Crocus::ShJoin.new('j2', [j1, t], [[2],[0]]) do |i|
       outs << i.flatten
     end
     r.set_block{|i| j1.insert(i,r)}
     s.set_block{|i| j1.insert(i,s)}
     t.set_block{|i| j2.insert(i,t)}
     j1.set_block{|i| j2.insert(i.flatten,j1)}
     
     r.insert([1,:a])
     s.insert([1,:b])
     t.insert([1,:c])
     r.insert([2,:a])
     s.insert([2,:b])
     t.insert([2,:c])
     r.flush; s.flush; t.flush; j1.flush; j2.flush
     assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
   end
end
    