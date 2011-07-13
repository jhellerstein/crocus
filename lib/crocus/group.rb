require 'crocus/elements'

class Crocus
  class PushGroup < PushElement
    def initialize(name, arity, inputs_in, keys_in, aggpairs_in, &blk)
      super(name, arity, *inputs_in, &blk)
      @groups = {}
      @keys = keys_in
      @keys = [] if keys_in.nil?
      @aggpairs = aggpairs_in
    end
  
    def insert(item)
      key = @keys.map{|k| item[k]}
      @aggpairs.each_with_index do |ap, agg_ix|
        agg_input = item[ap[1]]
        agg = @groups[key].nil? ? ap[0].send(:init, agg_input) : ap[0].send(:trans, @groups[key][agg_ix], agg_input)[0]
        @groups[key] ||= Array.new(@aggpairs.length)
        @groups[key][agg_ix] = agg
        @blk.call(nil)
      end
    end
    
    def flush
      @groups.each do |g, grps|
        grp = [g]
        @aggpairs.each_with_index do |ap, agg_ix|
          grp << ap[0].send(:final, grps[agg_ix])
        end
        @blk.call(grp.flatten)
      end
    end
  end
  
  class PushArgAgg < PushGroup
    def initialize(name, arity, inputs_in, keys_in, aggpairs_in, &blk)
      raise "Multiple aggpairs #{aggpairs_in.map{|a| a.class.name}} in ArgAgg; only one allowed" if aggpairs_in.length > 1
      super(name, arity, inputs_in, keys_in, aggpairs_in, &blk)
      @agg = @aggpairs[0][0]
      @aggcol = @aggpairs[0][1]
      @winners = {}
    end
    
    def insert(item)
      key = @keys.map{|k| item[k]}
      @aggpairs.each_with_index do |ap, agg_ix|
        agg_input = item[ap[1]]
        if @groups[key].nil?
          agg = ap[0].send(:init, agg_input)
          @winners[key] = item
        else
          agg_result = ap[0].send(:trans, @groups[key][agg_ix], agg_input)
          agg = agg_result[0]
          case agg_result[1]
          when :ignore
            # do nothing
          when :replace
            @winners[key] = [item]
          when :keep
            (@winners[key] ||= []) << item
          else
            raise "strange result from argagg finalizer" unless agg_result[1].class == Array and agg_result[1][0] == :delete
            agg_result[1][1..-1].each do |t|
              @winners[key].delete t unless @winners[key].nil
            end
          end
        end
        @groups[key] ||= Array.new(@aggpairs.length)
        @groups[key][agg_ix] = agg
        @blk.call(nil)
      end      
    end 
    
    def flush
      @groups.keys.each {|g| @blk.call(@winners[g])}
    end
  end

  ######## Agg definitions
  class Agg #:nodoc: all
    def init(val)
      val
    end
    
    # In order to support argagg, trans must return a pair:
    #  1. the running aggregate state
    #  2. a flag to indicate what the caller should do with the input tuple for argaggs
    #     a. :ignore tells the caller to ignore this input
    #     b. :keep tells the caller to save this input
    #     c. :replace tells the caller to keep this input alone
    #     d. [:delete, t1, t2, ...] tells the caller to delete the remaining tuples
    #  For things that do not descend from ArgExemplary, the 2nd part can simply be nil.
    def trans(the_state, val)
      return the_state, :ignore
    end

    def final(the_state)
      the_state
    end
  end

  class Exemplary < Agg #:nodoc: all
  end

  # ArgExemplary aggs are used by argagg. Canonical examples are min/min (argmin/max)
  # They must have a trivial final method and be monotonic, i.e. once a value v
  # is discarded in favor of another, v can never be the final result

  class ArgExemplary < Agg #:nodoc: all
    def tie(the_state, val)
      (the_state == val)
    end
    def final(the_state)
      the_state
    end
  end

  class Min < ArgExemplary #:nodoc: all
    def trans(the_state, val)
      if the_state < val 
        return the_state, :ignore
      else 
        return val, :replace
      end
    end
  end
  # exemplary aggregate method to be used in Bud::BudCollection.group.  
  # computes minimum of x entries aggregated.
  def min(x)
    [Min.new, x]
  end

  class Max < ArgExemplary #:nodoc: all
    def trans(the_state, val)
      if the_state > val
        return the_state, :ignore
      else
        return val, :replace
      end
    end
  end
  # exemplary aggregate method to be used in Bud::BudCollection.group.  
  # computes maximum of x entries aggregated.
  def max(x)
    [Max.new, x]
  end

  class Choose < ArgExemplary #:nodoc: all
    def trans(the_state, val)
      if the_state.nil?
        return val, :replace
      else
        return the_state, :ignore
      end
    end
    def tie(the_state, val)
      false
    end
  end

  # exemplary aggregate method to be used in Bud::BudCollection.group.  
  # arbitrarily but deterministically chooses among x entries being aggregated.
  def choose(x)
    [Choose.new, x]
  end
  
  class ChooseRand < ArgExemplary #:nodoc: all
    @@reservoir_size = 1 # Vitter's reservoir sampling, k = 1
    def init(x=nil)
      the_state = {:cnt => 1, :vals => [x]}
    end
    
    def trans(the_state, val)
      the_state[:cnt] += 1
      if the_state[:cnt] < @@reservoir_size
        the_state[:vals] << val
        return the_state, :keep
      else
        j = rand(the_state[:cnt])
        if j < @@reservoir_size
          old_tup = the_state[:vals][j]
          the_state[:vals][j] = val 
          return the_state, [:delete, old_tup]
        else
          return the_state, :keep
        end
      end
    end
    def tie(the_state, val)
      true
    end
    def final(the_state)
      the_state[:vals][rand(the_state[@@reservoir_size])]
    end
  end

  # exemplary aggregate method to be used in Bud::BudCollection.group.  
  # randomly chooses among x entries being aggregated.
  def choose_rand(x=nil)
    [ChooseRand.new]
  end

  class Sum < Agg #:nodoc: all
    def trans(the_state, val)
      return the_state + val, nil
    end
  end
  
  # aggregate method to be used in Bud::BudCollection.group.  
  # computes sum of x entries aggregated.
  def sum(x)
    [Sum.new, x]
  end

  class Count < Agg #:nodoc: all
    def init(x=nil)
      1
    end
    def trans(the_state, x=nil)
      return the_state + 1, nil
    end
  end
  
  # aggregate method to be used in Bud::BudCollection.group.  
  # counts number of entries aggregated.  argument is ignored.
  def count(x=nil)
    [Count.new]
  end

  class Avg < Agg #:nodoc: all
    def init(val)
      [val, 1]
    end
    def trans(the_state, val)
      retval = [the_state[0] + val]
      retval << (the_state[1] + 1)
      return retval, nil
    end
    def final(the_state)
      the_state[0]*1.0 / the_state[1]
    end
  end
  
  # aggregate method to be used in Bud::BudCollection.group.  
  # computes average of a multiset of x values
  def avg(x)
    [Avg.new, x]
  end

  class Accum < Agg #:nodoc: all
    def init(x)
      [x]
    end
    def trans(the_state, val)
      the_state << val
      return the_state, nil
    end
  end
  
  # aggregate method to be used in Bud::BudCollection.group.  
  # accumulates all x inputs into an array
  def accum(x)
    [Accum.new, x]
  end
end
