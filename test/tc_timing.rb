require './test_common.rb'

class TestTiming < Test::Unit::TestCase
  def dont_test_pull_time
    e = Crocus::PullElement.new('p', 0, (1..1000000000))
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Numeric and inp%2 == 0
    end
    t1   = Time.now
    (0..1000000).each {i.next}
    t2 = Time.now
    puts "1M pulls: #{t2-t1} elapsed"
  end
  
  def test_push_time
    p = Crocus::PushElement.new('p', 1, []) do |inp|
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
    r = Crocus::PushElement.new('r', 1, [])
    e = Crocus::PushEddy.new([r], []) do |inp|
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
    r = Crocus::PushElement.new('r', 1, [])
    s = Crocus::PushElement.new('s', 1, [])
    e = Crocus::PushEddy.new([r,s], [[[r, [0]], [s, [0]]]]) do |inp|
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
  
  def test_binary_join_time
    r = Crocus::PushElement.new('r', 1, [])
    s = Crocus::PushElement.new('s', 1, [])
    j = Crocus::ShJoin.new('j', [r,s], [[0],[0]]) do |inp|
      if inp[0].class <= Numeric and inp[0]%2 == 0
        [inp[0]*2] 
      else
        [-1]
      end
    end
    r.set_block {|i| j.insert(i,r)}
    s.set_block {|i| j.insert(i,s)}
    t1 = Time.now
    (0..500000).each{|i| r.insert([i]); s.insert([i])}
    r.flush; s.flush; j.flush 
    t2 = Time.now

    puts "1M binary symmetric join pushes: #{t2-t1} elapsed"
  end
  
  def test_hash_array_insertion
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[[i]] = [i,:a]}
    t2 = Time.now
    puts "1M hash(array) insertions: #{t2-t1} elapsed" 
  end
  def test_hash_int_insertion
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[i] = [i,:a]}
    t2 = Time.now
    puts "1M hash(int) insertions: #{t2-t1} elapsed" 
  end
end
    