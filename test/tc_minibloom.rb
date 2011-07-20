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
    mb.rel1 << [:a,1]
    mb.rel2 << [:b,1]    
    mb.stop
    assert_equal([:a, :b, 1], results.pop)
    assert_equal([], results)
  end
end
    