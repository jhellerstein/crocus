require 'set'

class Crocus
  class ItemSet < Set
    def initialize(name, arity, pkey, enum=nil, &block)
      @name = name
      raise "ItemSet::initialize: arity must be an integer, is #{arity.inspect}" unless arity.class <= Fixnum
      @arity = arity
      unless pkey.class <= Array and pkey.map{|i| i.class <= Fixnum}.uniq == [true] and pkey.map{|i| i < @arity}.uniq == [true]
        raise "pkey must be an array of integers less than arity, is #{pkey.inspect}" 
      end
      @pkey = pkey
      @index = {}
      super(enum, &block)
      @hash.each{|i| index_add(i)}
    end
    
    def index_add(item)
      key = @pkey.map{|i| item[i]}
      if @index[key] and @index[key] != item
        raise "key violation: #{item.inspect} inserted (key #{key.inspect}), collides with #{@index[key].inspect}" 
      end
      @index[key] = item
    end
    
    def index_delete(o)
      key = @pkey.map{|i| o[i]} 
      @index.delete(o) 
    end
    
    def index_subtract(enum)
      do_with_enum(enum) do |o|
        index_delete(o)
      end
      self
    end
    
    undef &
    undef -
    undef ^
    
    
    def add(i)
      index_add(i)
      super(i)
    end
    def <<(i)
      add i
    end
    def add?(i)
      index_add(i) unless include? i
      super(i)
    end
    
    def clear
      @index.clear
      super
    end
    
    undef collect!
    
    def delete(o)
      index_delete(o)
      super(o)
    end
    
    def delete?(o)
      index_delete(o) if include? o
      super(o)
    end
    
    def delete_if(o)
      block_given? or return enum_for(__method__)
      to_a.each {|o| index_delete(o) if yield(o)}
      super(o)
    end
    
    undef divide
    undef flatten!
    undef initialize_copy
    
    def keep_if
      block_given? or return enum_for(__method__)
      to_a.each { |o| index_delete(o) unless yield(o) }
      super
    end
       
    def merge(enum)
      if enum.instance_of?(self.class) and enum.key == @key
        @index.update(enum.instance_variable_get(:@index))
      else
        do_with_enum(enum) { |o| index_add(o) }
      end
      super(enum)
    end
      
    def replace(enum)
      if enum.class == self.class
        @index.replace(enum.instance_eval { @hash })
      end
      super(enum)
    end
    
    def subtract(i)
      super(i)
      index_subtract(i)
    end
         
    def [](key)
      @index[key]
    end
  end
end
