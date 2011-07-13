BUFSIZE = 1000

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
    attr_reader :name, :arity
    def initialize(name, arity, *innies, &blk)
      @name = name
      @arity = arity
      @inputs = innies
      @blk = blk
    end
    def set_block(&blk)
      @blk = blk
    end
    def wire_to(element)
      @blk = lambda{|i| element.insert(i,self)}
    end
    def insert(item, caller=nil)
      raise "PushElement #{@name} has no block" if @blk.nil?
      @blk.call(item) unless item.nil? or item == []
    end
    def <<(i)
      insert(i, nil)
    end
    def flush
    end
    undef to_enum
  end
end