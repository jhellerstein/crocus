require './test_common.rb'
require '../lib/crocus/minibloom'

class TestMiniBloom < Test::Unit::TestCase
  def test_single_table
    results = []
    mb = MiniBloom.new
    mb.source('p1',1)
    mb.p1.pro {|i| results << [2*i[0]]}
    mb.p1 << [2]
    mb.stop
    assert_equal([4], results.pop)
  end
  def test_join
    results = []
    mb = MiniBloom.new
    mb.source('rel1',2)
    mb.source('rel2',2)
    (mb.rel1*mb.rel2).pairs([1]=>[1]).pro {|i| results << [i[0], i[2], i[3]]}
    mb.rel1 <= [['a',1], ['c', 3]]
    mb.rel2 << ['b',1]    
    mb.stop
    assert_equal(['a', 'b', 1], results.pop)
    assert_equal([], results)
  end
  def test_cross_product
    results = []
    mb = MiniBloom.new
    mb.source('rel1',2)
    mb.source('rel2',2)
    (mb.rel1*mb.rel2).pairs.pro {|i| results << i}
    mb.rel1 <= [['a',1], ['c', 3]]
    mb.rel2 << ['b',1]    
    mb.stop
    assert_equal([['a', 1, 'b', 1],['c',3, 'b',1]], results.sort)
  end
  def test_two_joins
    outs = []
    mb = MiniBloom.new
    mb.source('rel1',2)
    mb.source('rel2',2)
    mb.source('rel3',2)
    ((mb.rel1*mb.rel2).pairs([0]=>[0]) * mb.rel3).pairs([2]=>[0]).pro do |i|
      outs << i
    end
    mb.rel1 <= [[1,:a],[2,:a]]
    mb.rel2 <= [[1,:b],[2,:b]]
    mb.rel3 <= [[1,:c],[2,:c]]
    mb.stop
    assert_equal([[1, :a, 1, :b, 1, :c], [2, :a, 2, :b, 2, :c]], outs.sort)
  end
  require 'set'
  def test_recursion
    outs = Set.new
    links = Set.new
    mb = MiniBloom.new
    mb.source('link', 2)
    mb.source('path', 2)
    mb.path <= mb.link
    mb.path <= (mb.link*mb.path).pairs([1]=>[0]).pro do |i|
      tup = [i[0], i[3]]
      unless outs.include? tup
        outs << tup
        tup
      else
        nil
      end
    end
    [[1,2],[2,3],[3,4],[6,7],[2,7]].each{|i| links << i}
    mb.link <= links
    mb.stop
    assert_equal([[1,2],[1,3],[1,4],[1,7],[2,3],[2,4],[2,7],[3,4],[6,7]], (outs+links).to_a.sort)
  end
  
  def test_group_by
    outs = []
    mb = MiniBloom.new
    mb.source('r',2)
    mb.r.group([1], Crocus::sum(0)) {|i| outs << i unless i.nil?}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal([['a', 3],['c', 2]], outs.sort)      
  end
  def test_agg_nogroup
    outs = []
    mb = MiniBloom.new
    mb.source('r',2)
    mb.r.group([], Crocus::sum(0)) {|i| outs << i unless i.nil?}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal([[5]], outs.sort)
  end
  def test_argagg
    agg_outs = []
    max_outs = []
    min_outs = []
    mb = MiniBloom.new
    mb.source('r',2)
    mb.r.argagg([1], Crocus::min(0)) {|i| agg_outs << i unless i.nil?}
    mb.r.argmin([1], 0) {|i| min_outs << i unless i.nil?}
    mb.r.argmax([1], 0) {|i| max_outs << i unless i.nil?}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal([[1,'a'],[2,'c']], agg_outs.sort)      
    assert_equal([[1,'a'],[2,'c']], min_outs.sort)      
    assert_equal([[2,'a'],[2,'c']], max_outs.sort)      
  end
  def test_argagg_nogroup
    outs = []
    mb = MiniBloom.new
    mb.source('r',2)
    mb.r.argagg([], Crocus::min(0)) {|i| outs << i unless i.nil?}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal([[1,'a']], outs)
  end
  def test_preds
    mb = MiniBloom.new
    mb.source('r',2)
    ex_outs = false
    inc_outs = false
    fail_outs = false
    mb.r.on_exists? {ex_outs = true}
    mb.r.on_include?([1,'a']) {inc_outs = true}
    mb.r.on_include?(['joe']) {fail_outs = true}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal(true, ex_outs)
    assert_equal(true, inc_outs)
    assert_equal(false, fail_outs)
  end
  def test_inspected
    outs = []
    mb = MiniBloom.new
    mb.source('r',2)
    mb.r.inspected.pro {|i| outs << i}
    mb.r <= [[1,'a'],[2,'a'],[2,'c']]
    mb.stop
    assert_equal([[1,'a'],[2,'a'],[2,'c']].map{|i| [i.inspect]}, outs)
  end
end
