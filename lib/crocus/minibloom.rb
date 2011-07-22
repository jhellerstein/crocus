class MiniBloom < Crocus
  attr_reader :crocus
  def initialize
    @crocus = Crocus.new(:ip => "127.0.0.1", :port => 5432)
    super
  end
  def run_bg
    @crocus.run_bg
  end
  # helper to define instance methods
  def singleton_class # :nodoc: all
    class << self; self; end
  end
  private
  def define_collection(name, &block)
    # Don't allow duplicate collection definitions
    if @collections.has_key? name
      raise "collection already exists: #{name}"
    end

    # Rule out collection names that use reserved words, including
    # previously-defined method names.
    reserved = eval "defined?(#{name})"
    unless reserved.nil?
      raise "symbol :#{name} reserved, cannot be used as table name"
    end
    self.singleton_class.send(:define_method, name) do |*args, &blk|
      unless blk.nil? then
        return @collections[name].pro(&blk)
      else
        return @collections[name]
      end
    end
  end
  public
  def table(name, schema=nil)
    define_collection(name)
    @collections[name] = Crocus::Table.new(name,self,schema)
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
      elem = Crocus::PushElement.new('project' + Time.new.tv_usec.to_s, -1)
      self.wire_to(elem)
      elem.set_block(&blk)
      return elem
    end
    def join(elem2, &blk)
      elem2 = elem2.to_push_elem unless elem2.class <= PushElement
      join = Crocus::PushSHJoin.new('join'+name+elem2.name+Time.new.tv_usec.to_s, arity+elem2.arity,
                                    [self,elem2], [], &blk)
      self.wire_to(join)
      elem2.wire_to(join)
      return join
    end
    def *(elem2, &blk)
      join(elem2, &blk)
    end
    def merge(source)
      if source.class <= PushElement
        source.wire_to(self)
      else 
        source.each{|i| self << i}
      end
    end
    alias <= merge
    def group(keycols, *aggpairs, &blk)
      g = Crocus::PushGroup.new('grp'+Time.new.tv_usec.to_s, keycols.length+aggpairs.length, keycols, aggpairs) do |i|
        blk.call(i)
      end
      self.wire_to(g)
      g
    end
    def argagg(keycols, aggpair, &blk)
      aa = Crocus::PushArgAgg.new('argagg'+Time.new.tv_usec.to_s, arity, keycols, [aggpair], &blk)
      self.wire_to(aa)
      return aa
    end
    def argmax(gbcols, col, &blk)
      argagg(gbcols, Crocus::max(col), &blk)
    end
    def argmin(gbcols, col, &blk)
      argagg(gbcols, Crocus::min(col), &blk)
    end
    alias on_exists? pro
    def on_include?(item, &blk)
      inc = pro{|i| blk.call(item) if i == item and not blk.nil?}
      wire_to(inc)
      inc
    end
    def inspected
      ins = Crocus::PushElement.new('inspected'+Time.new.tv_usec.to_s,1) {|i| [i.inspect]}
      self.wire_to(ins)
      return ins
    end
  end
  class PushSHJoin
    def pairs(preds=[],&blk)
      keys = preds.map{|x| x.to_a}[0]
      set_keys(keys)
      set_block(&blk) if blk
      self
    end
    alias combos pairs
  end
end
    
    
    