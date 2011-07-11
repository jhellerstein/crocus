require './test_common'
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
