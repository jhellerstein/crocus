require './test_common'
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
t2 = Time.now
puts "1M unary eddy pushes: #{t2-t1} elapsed"