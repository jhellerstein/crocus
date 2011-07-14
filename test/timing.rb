require './test_common'
r = Crocus::PushElement.new('r', 1)
s = Crocus::PushElement.new('s', 1)
e = Crocus::PushEddy.new('e', 2, [r,s], [[[r, [0]], [s, [0]]]]) do |inp|
  if inp[0].class <= Numeric and inp[0]%2 == 0
    [inp[0]*2] 
  else
    [-1]
  end    
end
t1 = Time.now
(0..500000).each{|i| r.insert([i,:a]); s.insert([i, :b])}
r.flush; s.flush; e.flush 
t2 = Time.now
puts "1M binary join eddy pushes: #{t2-t1} elapsed" 
