require './test_common.rb'

class TestItemSets < Test::Unit::TestCase
  def test_insert
    it = Crocus::ItemSet.new(:r, 2, [0])
    it << [1,:a]
    it << [2,:b]
    it << [2,:b]
    assert_raise(RuntimeError) {it << [1, :c]}
    it << [nil, :ha]
    assert_raise(RuntimeError) {it << []}
    it << [3]
    assert_equal([[1,:a], [2,:b], [nil, :ha], [3]], it.to_enum.map{|i| i})
  end  
end
    