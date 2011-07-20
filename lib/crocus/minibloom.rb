require 'test_common.rb'

class MiniBloom < Crocus
  attr_reader :crocus
  def initialize
    @crocus = Crocus.new(:ip => "127.0.0.1", :port => 5432)
    @crocus.run_bg
  end
  # helper to define instance methods
  def singleton_class # :nodoc: all
    class << self; self; end
  end
  def source(name, arity=-1)
    # Don't allow duplicate collection definitions
    if @crocus.sources.has_key? name
      raise "source already exists: #{name}"
    end

    # Rule out source names that use reserved words, including
    # previously-defined method names.
    reserved = eval "defined?(#{name})"
    unless reserved.nil?
      raise "string #{name} reserved, cannot be used as source name"
    end
    
    @crocus.sources[name] = Crocus::PushElement.new(name, arity)
    
    self.singleton_class.send(:define_method, name.to_sym) { @crocus.sources[name] }
  end
  def insert(item)
    self.send(item[0].to_sym) << item[1]
  end
  def <<(i)
    insert(i)
  end
  def stop
    @crocus.sources.each{|k,v| v.end}
    @crocus.stop_bg
  end
end

class Crocus
  class PushElement
    def pro(&blk)
      elem = Crocus::PushElement.new('project' + Time.now.to_s, -1)
      self.wire_to(elem)
      elem.set_block(&blk)
      return elem
    end
    def *(elem2, &blk)
      join = Crocus::PushSHJoin.new('join'+name+elem2.name+Time.now.to_s, arity+elem2.arity,
                                    [self,elem2], [], &blk)
      self.wire_to(join)
      elem2.wire_to(join)
      return join
    end
  end
  class PushSHJoin
    def pairs(preds)
      keys = preds.map{|x| x.to_a}[0]
      set_keys(keys)
    end
    alias combos pairs
  end
end
    
    
    