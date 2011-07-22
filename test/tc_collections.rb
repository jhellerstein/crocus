require './test_common.rb'
require '../lib/crocus/minibloom'

class TestCollections < Test::Unit::TestCase
  def test_collection
    mb = Crocus.new(:ip=>'localhost', :port=>5432)
    c = Crocus::Collection.new('c', mb)
    exercise_methods(c)
  end
  def test_table
    mb = Crocus.new(:ip=>'localhost', :port=>5432)
    c = Crocus::Table.new('c', mb, [:key]=>[:val])
    exercise_methods(c)
  end
  def exercise_methods(c)
    c << [1,2]
    c <= [[2,3]]
    c.tick_deltas
    c.tick_deltas
    assert_equal([[1,2],[2,3]], c.to_a)
    assert_equal([[1],[2]], c.map{|t| [t.key]})
    assert(c.has_key?([1]), "has_key? predicate failed")
    assert(c.exists? {|t| t.key == 1}, "exists? predicate failed")
    assert(c.include?([2,3]), "include? predicate failed")
    assert_equal([[1],[2]], c.keys)
    assert_equal([[2],[3]], c.values)
    assert_equal([:key], c.key_cols)
    assert_equal([["[1, 2]"], ["[2, 3]"]], c.inspected)
    assert_equal([1,2], c[[1]])
  end
end
    