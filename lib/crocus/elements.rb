BUFSIZE = 1000
require "set"

class Crocus
  # pattern taken from 
  # http://en.wikibooks.org/wiki/Ruby_Programming/Reference/Objects/Enumerable#Lazy_evaluation
  # Usage example:
  # e = PullElement.new((1..1000000000))
  # i = e.to_enum do |out, inp|
  #  out.yield [inp] if inp.class <= Numeric and inp%2 == 0
  # end
  # i.next
  class PullElement
    attr_reader :name, :arity
    def initialize(name, arity, *innies)
      @name = name
      @arity = arity
      @inputs = innies
    end
    # by default, PullElements form the MultiSet Union (concatenation) of their inputs
    def each
      @inputs.each do |inny|
        inny.each do |i|
          yield i
        end
      end
    end
    def to_enum(&blk)
      Enumerator.new do |y|
        each do |*input|
          blk.call(y, *input)
        end
      end
    end
  end

  # Usage example:
  # p = PushElement.new(:r) do |inp|
  #   puts "in block"
  #   [inp] if inp.class <= Numeric and inp%2 == 0
  # end
  # p.insert(2)
  # p.insert(1)
  # p.insert(nil)
  class PushElement
    @@count = 0
    
    attr_reader :name, :arity, :inputs
    def initialize(name, arity, &blk)
      @name = name
      @arity = arity
      @blk = blk
      @outputs = []
    end
    def self.count
      @@count
    end
    def self.reset_count
      @@count=0
    end
    def set_block(&blk)
      @blk = blk
    end
    def wire_to(element)
      raise "attempt to wire_to non-PushElement" unless element.class <= PushElement
      @outputs << element
    end
    def insert(item, source=nil)
      push_out(item)
    end
    def push_out(item)
      raise "no output specified for PushElement #{@name}" if @blk.nil? and @outputs == []
      # puts "inserting #{item.inspect}"
      unless item.nil? or item == []
        @@count += 1
        out = @blk.nil? ? item : @blk.call(item) 
        @outputs.each{|o| o.insert(out,self)} unless out.nil?
      end
    end
    def <<(i)
      insert(i, nil)
    end
    # flushes should always be propagated downstream.  
    def flush
      # avoid flush cycles via the @flushing flag
      if @flushing.nil?
        @flushing = true
        local_flush
        @outputs.each {|o| o.flush}
      end
      @flushing = nil
    end
    # flush should ensure that any deferred inserts are processed.
    # it is *not* a promise of end-of-stream.
    def local_flush
    end
    # ends should be handled carefully
    def end(source=nil)
      if @ended.nil?
        @ended = true
        flush
        if local_end(source)
          @outputs.each {|o| o.end(self)}
        end
      end
    end
    def local_end(source)
      true
    end
    undef to_enum
  end  
  
  class ScannerElement < PushElement
    def initialize(name, arity, collection_in, &blk)
      super(name,arity)
      @collection = collection_in
    end
    def insert(item, source=nil)
      # puts "scanner #{name} beginning push"
      @collection.each {|item| push_out(item)}
    end
  end
end