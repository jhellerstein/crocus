require './test_common.rb'
require 'crocus/stem'
require 'crocus/joineddy'

class TestTiming < Test::Unit::TestCase
  def test_timing
    iterations = 5
    items_to_push = 1000000
    outs = []
    puts "About to run #{iterations} iterations of #{items_to_push} items each"
    puts
    iterations.times do |i|
      puts "iteration #{i}"
      puts "============"      
      outs << run_suite(items_to_push)
    end
    puts
    puts "Summary"
    puts "======="
    outs.each_with_index do |o, i|
      puts o[0].inspect if i == 0
      puts o[1].inspect
    end
  end
  
  def run_suite(items_to_push)
    routines = [[:hash_array_insertion, "hash(array) insertions"],
                [:hash_int_insertion, "hash(int) insertions"],
                [:push_time, "pushes"],
                [:unary_eddy_time, "unary StemEddy pushes"],
                [:binary_eddy_time, "binary StemEddy pushes"],
                [:binary_join_time, "binary SHJoin pushes"],
                [:binary_join_eddy_time, "binary JoinEddy pushes"],
                [:group_time, "group pushes"],
                [:binary_join_EM_time, "binary join pushes thru EM"]]
                    
    routines.each do |r|
      print "#{items_to_push} #{r[1]}: "
      elapsed = self.send r[0], items_to_push
      puts "#{elapsed} elapsed"
      r << elapsed
    end
  
    return ([routines.map{|r| r[0]}, routines.map{|r| r[2]}])
  end
  
  def process_item(inp)
    return nil if inp.nil?
    if inp[0].class <= Numeric and inp[0]%2 == 0
      [inp[0]*2] 
    else
      [-1]
    end
  end
  
  def pull_time(items_to_push)
    e = Crocus::PullElement.new('p', 0, (1..1000000000))
    i = e.to_enum do |out, inp|
      out.yield inp if inp.class <= Numeric and inp%2 == 0
    end
    t1   = Time.now
    (0..items_to_push).each {i.next}
    t2 = Time.now
    return t2-t1
  end
  
  def hash_array_insertion(items_to_push)
    h = {}
    t1 = Time.now
    (0..items_to_push).each{|i| h[[i]] = [i,:a]}
    t2 = Time.now
    return t2-t1
  end
  def hash_int_insertion(items_to_push)
    h = {}
    t1 = Time.now
    (0..items_to_push).each{|i| h[i] = [i,:a]}
    t2 = Time.now
    return t2-t1
  end
  
  def push_time(items_to_push)
    p = Crocus::PushElement.new('p', 1) do |inp|
      process_item(inp)
    end
    t1 = Time.now
    (0..items_to_push).each {|i| p.insert([i])}
    p.end
    t2 = Time.now
    return t2-t1
  end
  
  def unary_eddy_time(items_to_push)
    r = Crocus::PushElement.new('r', 1)
    e = Crocus::PushStemEddy.new('e', 1, [r], []) do |inp|
      process_item(inp)
    end
    r.wire_to(e)
    t1 = Time.now
    (0..items_to_push).each{|i| r.insert([i])}
    r.end; e.end
    t2 = Time.now
    return t2-t1
  end
  def binary_eddy_time(items_to_push)
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    e = Crocus::PushStemEddy.new('e', 2, [r,s], [[[r, [0]], [s, [0]]]]) do |inp|
      process_item(inp)  
    end
    r.wire_to(e)
    s.wire_to(e)
    t1 = Time.now
    (0..items_to_push/2).each{|i| r.insert([i,:a]); s.insert([i, :b])}
    r.end; s.end
    t2 = Time.now
    return t2-t1
  end  
  
  def binary_join_time(items_to_push)
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    j = Crocus::PushSHJoin.new('j', 2, [r,s], [[0],[0]]) do |inp|
      process_item(inp)
    end
    r.wire_to(j)
    s.wire_to(j)
    t1 = Time.now
    (0..items_to_push/2).each{|i| r.insert([i]); s.insert([i])}
    r.end; s.end
    t2 = Time.now
    return t2-t1
  end
  
  def binary_join_eddy_time(items_to_push)
    r = Crocus::PushElement.new('r', 1)
    s = Crocus::PushElement.new('s', 1)
    e = Crocus::PushJoinEddy.new('e', 2, [r,s], [[[r, [0]], [s, [0]]]]) do |inp|
      process_item(inp)  
    end
    r.wire_to(e)
    s.wire_to(e)
    t1 = Time.now
    (0..items_to_push/2).each{|i| r.insert([i,:a]); s.insert([i, :b])}
    r.end; s.end
    t2 = Time.now
    return t2-t1
  end
  
  def group_time(items_to_push)
    p = Crocus::PushElement.new('p', 1) 
    g = Crocus::PushGroup.new('g', 1, nil, [[Crocus::Count.new, 0]]) do |inp|
      process_item(inp)
    end
    p.wire_to(g)
    t1 = Time.now
    (0..items_to_push).each {|i| p.insert([i])}
    p.end
    t2 = Time.now
    return t2-t1
  end
  
  def binary_join_EM_time(items_to_push)
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
      (1..items_to_push/2).each do |i| 
        engine.dsock.send_datagram(['r', [i]].to_msgpack, engine.ip, engine.port)
        engine.dsock.send_datagram(['s', [i]].to_msgpack, engine.ip, engine.port)
      end
    end
    i = 0
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

      if Crocus::PushElement.count >= items_to_push - 10
        r.end; s.end
        t2 = Time.now
        break
      end
      sleep 1
       i += 1
      if i > 60
        t2 = Time.now
        break
      end
    end
    engine.stop_bg
    return t2-t1
  end
end
    