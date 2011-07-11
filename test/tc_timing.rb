require './test_common.rb'

class TestTiming < Test::Unit::TestCase
  def dont_test_pull_time
    e = Blossom::PullElement.new('p', 0, (1..1000000000))
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Numeric and inp%2 == 0
    end
    t1   = Time.now
    (0..1000000).each {i.next}
    t2 = Time.now
    puts "1M pulls: #{t2-t1} elapsed"
  end
  
  def test_push_time
    p = Blossom::PushElement.new('p', 1, []) do |inp|
      if inp[0].class <= Numeric and inp[0]%2 == 0
        [inp[0]*2] 
      else
        [-1]
      end
    end
    t1 = Time.now
    (0..1000000).each {|i| p.insert([i])}
    p.flush
    t2 = Time.now
    puts "1M pushes: #{t2-t1} elapsed"
  end
  
  def test_unary_eddy_time
    r = Blossom::PushElement.new('r', 1, [])
    e = Blossom::PushEddy.new([r], []) do |inp|
      if inp[0].class <= Numeric and inp[0]%2 == 0
        [inp[0]*2] 
      else
        [-1]
      end    
    end
    t1 = Time.now
    (0..1000000).each{|i| e.insert([i], r)}
    r.flush; e.flush
    t2 = Time.now
    puts "1M unary eddy pushes: #{t2-t1} elapsed" 
  end
  def test_binary_eddy_time
    r = Blossom::PushElement.new('r', 1, [])
    s = Blossom::PushElement.new('s', 1, [])
    e = Blossom::PushEddy.new([r,s], [[[r, [0]], [s, [0]]]]) do |inp|
      if inp[0].class <= Numeric and inp[0]%2 == 0
        [inp[0]*2] 
      else
        [-1]
      end    
    end
    t1 = Time.now
    (0..500000).each{|i| e.insert([i,:a], r); e.insert([i, :b], s)}
    r.flush; s.flush; e.flush 
    t2 = Time.now
    puts "1M binary join eddy pushes: #{t2-t1} elapsed" 
  end  
  def test_array_hash_insertion
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[[i]] = [i,:a]}
    t2 = Time.now
    puts "1M array-hash insertions: #{t2-t1} elapsed" 
  end
  def test_int_hash_insertion
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[i] = [i,:a]}
    t2 = Time.now
    puts "1M int-hash insertions: #{t2-t1} elapsed" 
  end
end
    