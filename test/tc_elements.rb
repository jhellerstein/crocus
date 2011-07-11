require './test_common.rb'

class TestElements < Test::Unit::TestCase
  def test_pull_element
    e = Crocus::PullElement.new(:p, 0, (1..1000000000))
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Numeric and inp%2 == 0
    end
    assert_equal([2,4,6], i.take(3))
  end
  
  def test_push_element
    results = []
    p = Crocus::PushElement.new(:r,0,[]) do |inp|
      if inp[0].class <= Numeric and inp[0]%2 == 0
        results << [inp[0]*2] 
      else
        results << [-1]
      end
    end
    p.insert([2])
    p.flush
    assert_equal([4], results.pop)
    p.insert([1])
    p.flush
    assert_equal([-1], results.pop)
    p.insert([:a])
    p.flush
    assert_equal([-1], results.pop)
    p.insert(nil)
    p.flush
    assert_equal(nil, results.pop)
  end
  
  def test_pull_itemset
    it = Crocus::ItemSet.new(:r,2,[0])
    (0..1000).each do |i|
      it << [i,i+1]
    end
    e = Crocus::PullElement.new(:p, 0, it)
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Array and inp[0].class <= Numeric and inp[0]%2 == 0
    end
    assert_equal([[0,1],[2,3],[4,5]], i.take(3))
  end
end
    