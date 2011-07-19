require './test_common.rb'
require 'crocus/stem'
require 'crocus/joineddy'

class TestTiming < Test::Unit::TestCase
  def process_item(inp)
    return nil if inp.nil?
    if inp[0].class <= Numeric and inp[0]%2 == 0
      [inp[0]*2] 
    else
      [-1]
    end
  end
  
  # def test_timing_suite
  
  def dont_test_pull_time
    print "1M pulls: "
    e = Crocus::PullElement.new('p', 0, (1..1000000000))
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Numeric and inp%2 == 0
    end
    t1   = Time.now
    (0..1000000).each {i.next}
    t2 = Time.now
    puts "#{t2-t1} elapsed"
  end
  
  def test_1_hash_array_insertion
    print "1M hash(array) insertions: "
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[[i]] = [i,:a]}
    t2 = Time.now
    puts "#{t2-t1} elapsed" 
  end
  def test_1_hash_int_insertion
    print "1M hash(int) insertions: "
    h = {}
    t1 = Time.now
    (0..1000000).each{|i| h[i] = [i,:a]}
    t2 = Time.now
    puts "#{t2-t1} elapsed" 
  end
  
  def test_0_push_time
    print "1M pushes: "
    p = Crocus::PushElement.new('p', 1) do |inp|
      process_item(inp)
    end
    t1 = Time.now
    (0..1000000).each {|i| p.insert([i])}
    p.end
    t2 = Time.now
    puts "#{t2-t1} elapsed"
  end
  
  def test_unary_eddy_time
    print "1M unary eddy pushes: "
    r = Crocus::PushElement.new('r', 1)
    e = Crocus::PushStemEddy.new('e', 1, [r], []) do |inp|
      process_item(inp)
    end
    r.wire_to(e)
    t1 = Time.now
    (0..1000000).each{|i| r.insert([i])}
    r.end; e.end
    t2 = Time.now
    puts "#{t2-t1} elapsed" 
  end
  def test_binary_eddy_time
    print "1M binary join StemEddy pushes: "
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    e = Crocus::PushStemEddy.new('e', 2, [r,s], [[[r, [0]], [s, [0]]]]) do |inp|
      process_item(inp)  
    end
    r.wire_to(e)
    s.wire_to(e)
    t1 = Time.now
    (0..500000).each{|i| r.insert([i,:a]); s.insert([i, :b])}
    r.end; s.end
    t2 = Time.now
    puts "#{t2-t1} elapsed" 
  end  
  
  def test_binary_join_time
    print "1M binary symmetric join pushes: "
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    j = Crocus::PushSHJoin.new('j', 2, [r,s], [[0],[0]]) do |inp|
      process_item(inp)
    end
    r.wire_to(j)
    s.wire_to(j)
    t1 = Time.now
    (0..500000).each{|i| r.insert([i]); s.insert([i])}
    r.end; s.end
    t2 = Time.now

    puts "#{t2-t1} elapsed"
  end
  
  def test_binary_join_eddy_time
    print "1M binary join JoinEddy pushes: "
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    e = Crocus::PushJoinEddy.new('e', 2, [r,s], [[[r, [0]], [s, [0]]]]) do |inp|
      process_item(inp)  
    end
    r.wire_to(e)
    s.wire_to(e)
    t1 = Time.now
    (0..500000).each{|i| r.insert([i,:a]); s.insert([i, :b])}
    r.end; s.end
    t2 = Time.now
    puts "#{t2-t1} elapsed" 
  end
  
  def test_group_time
    print "1M group pushes: "
    p = Crocus::PushElement.new('p', 1) 
    g = Crocus::PushGroup.new('g', 1, nil, [[Crocus::Count.new, 0]]) do |inp|
      process_item(inp)
    end
    p.wire_to(g)
    t1 = Time.now
    (0..1000000).each {|i| p.insert([i])}
    p.end
    t2 = Time.now
    puts "#{t2-t1} elapsed"
  end
  
  def test_zz_binary_join_EM_time
    print "1M binary join pushes through EventMachine: "

    halflife = 500000
    joincount = 0

    engine = Crocus.new(:ip => "127.0.0.1", :port => 5432)
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    engine.register_source(r)
    engine.register_source(s)
    engine.run_bg
    j = Crocus::PushSHJoin.new('j', 2, [r,s], [[0],[0]]) do |inp|
      joincount += 1
    end
    r.wire_to(j)
    s.wire_to(j)
    t1 = Time.now
    t2 = nil
    engine.schedule_and_wait do
      (0..halflife-1).each do |i| 
        engine.dsock.send_datagram(['r', [i]].to_msgpack, engine.ip, engine.port)
        engine.dsock.send_datagram(['s', [i]].to_msgpack, engine.ip, engine.port)
      end
    end
    loop do
      # print "running "
      # prog = Crocus::PushElement.count*40 / (2*halflife)
      # prog.times {print "="}
      # pct = prog*100/40
      # print pct
      # spc = (pct / 10 == 0) ? 1 : (pct < 10 ? 2 : 3)
      # (40-(prog+spc)).times {print "-"} unless pct > 99
      # print "\r"
      # $stdout.flush

      if Crocus::PushElement.count >= 2*halflife - 10
        r.end; s.end
        t2 = Time.now
        break
      end
      sleep 1
    end
    # puts "inserted #{Crocus::PushElement.count} items"
    # puts "produced #{joincount} items"
    puts "~ #{(t2-t1)} elapsed" 
  end
end
    