require './test_common.rb'

class TestJoins < Test::Unit::TestCase
  def test_PushSHJoin
     outs = []
     r = Crocus::PushElement.new('r', 2, [])
     s = Crocus::PushElement.new('s', 2, [])
     j = Crocus::PushSHJoin.new('j', 4, [r,s], [[0],[1]]) do |i|
       outs << i
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
     j1 = Crocus::PushSHJoin.new('j1', 4, [r,s], [[0],[0]])
     j2 = Crocus::PushSHJoin.new('j2', 6, [j1, t], [[2],[0]]) do |i|
       outs << i
     end
     r.set_block{|i| j1.insert(i,r)}
     s.set_block{|i| j1.insert(i,s)}
     t.set_block{|i| j2.insert(i,t)}
     j1.set_block{|i| j2.insert(i,j1)}
     
     r.insert([1,:a])
     s.insert([1,:b])
     t.insert([1,:c])
     r.insert([2,:a])
     s.insert([2,:b])
     t.insert([2,:c])
     r.flush; s.flush; t.flush; j1.flush; j2.flush
     assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
   end
   
   require 'set'
   def test_recursion
     outs = Set.new
     links = Set.new
     link = Crocus::PushElement.new('link', 2, [])
     path = Crocus::PushElement.new('path', 2, [])
     j = Crocus::PushSHJoin.new('jpath', 4, [link,path], [[1],[0]]) do |i|
       tup = [i[0], i[3]]
       unless outs.include? tup
         outs << tup
         path << tup
       end
     end
     link.set_block{|l| j.insert(l, link)}
     path.set_block{|p| j.insert(p, path)}
     links << ([1,2])
     links << ([2,3])
     links << ([3,4])
     links << ([6,7])
     links << ([2,7])
     links.each {|l| link << l; path << l}
     link.flush; path.flush; j.flush
     assert_equal([[1,2],[1,3],[1,4],[1,7],[2,3],[2,4],[2,7],[3,4],[6,7]], (outs+links).to_a.sort)
   end
end
    