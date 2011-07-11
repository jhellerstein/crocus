require 'crocus/elements'

BUFSIZE = 1000

class Crocus
  class EddyItemSet
    # and ItemSet is a set of (possibly partially empty) result tuple-arrays, which
    # share the same sources and ready/done status
    attr_accessor :items, :ready, :done, :source_name, :source_id
    def initialize(itemset_in, source_name_in, source_id_in, stems_in)
      @items = itemset_in
      @source_name = source_name_in
      @source_id = source_id_in
      @ready = 2**source_id_in # ready to route to self
      # puts "@all_on = #{@all_on}"
      @done = 0
    end
    def each
      @items.each
    end
  end
  
  class Stem < PushElement
    attr_reader :key, :my_id, :my_bit
    def initialize(name, arity, key, eddy, &blk)
      @items = {}
      @key = key
      @eddy = eddy
      @my_id = eddy.name_to_id[name]
      @my_bit = 2**@my_id
      super(name, arity, [], &blk)
    end
    
    def insert(itemset, key_cols)      
      if itemset.source_name == @name
        # insert into itemset and call @blk
        # puts "inserting #{item.item.inspect} into Stem #{@name}"
        # key = @key.map{|i| item.item[item.source_id][i]}
        itemset.items.each do |item|
          subitem = item[itemset.source_id]
          # key = key_cols.map{|i| subitem[i]}          
          key = key_cols.nil? ? [] : [subitem[key_cols[0]]]
          (@items[key] ||= []) << subitem
        end
        @blk.call(itemset)
      else
        # find matches and route resulting concatenation via calling @blk
        # puts "looking for key #{key.inspect} in #{@name}"
        newitems = []
        itemset.items.each do |item|
          subitem = item[itemset.source_id]
          # key = key_cols.nil? ? [] : key_cols.map{|i| subitem[i]} 
          key = key_cols.nil? ? [] : [subitem[key_cols[0]]]
          matches = @items[key]
          unless matches.nil?
            matches.each do |i|
              item[@my_id] = i
              newitem = item.clone
              newitems << newitem
            end
          end
        end 
        itemset.items = newitems
        @blk.call(itemset)
      end
    end
      
    def <<(i)
      insert(i)
    end
  end

  class PushEddy < PushElement
    attr_reader :id_to_name, :name_to_id, :all_on, :init_ready, :id_to_preds
    attr_accessor :curid
    # innies is an array of PushElements that push back to the Eddy
    # preds is an array of attribute pairs of the form [[push_elem, key], [push_elem, key]]
    def initialize(innies, preds, &blk)
      @elements = []
      @inputs = innies
      @preds = preds
      @stems = {}
      @id_to_name = {}
      @name_to_id = {}
      @curid = 0
      @blk = blk
      @id_to_preds = {}
      @ids = (0..@inputs.length-1) # precompute this outside the insert path!
      
      counts = @inputs.reduce({}) do |memo,i|
        memo[i.name] ||= 0
        memo[i.name] += 1
        memo
      end
      counts = counts.map{|k,v| k if v > 1}.compact
      raise "duplicated input names #{counts.inspect} in Eddy initializer" if counts.length > 0
      
      @input_bufs = {}
      inputs_left = {}
      @all_on = 0
      @inputs.each_with_index do |inp, i| 
        # set up a buffer for each input
        @input_bufs[i] = []     
        # set self.route to be the continuation blk for each input
        inp.set_block { |item| self.insert(item, inp) }
        # keep track of the inputs we haven't made a stem for yet
        (inputs_left[inp.name] ||= []) << inp
        # add up all the input bits
        @all_on += 2**i
      end
      
      # for each pred, make sure we have an appropriately-keyed stem
      @preds.each do |l, r|
        register_stem(l[0].name, l[0].arity, l[1])
        inputs_left[l[0].name].pop
        register_stem(r[0].name, r[0].arity, r[1])
        inputs_left[r[0].name].pop
        (id_to_preds[name_to_id[l[0].name]] ||= []) << [2**name_to_id[r[0].name], r[1]]
        (id_to_preds[name_to_id[r[0].name]] ||= []) << [2**name_to_id[l[0].name], l[1]]
      end
      
      # any inputs that are left will have a stem that we'll need to scan
      inputs_left.each do |k,v|
        v.each do |i|
          register_stem(i.name, i.arity, []) # empty key will hash all entries together on nil
        end
      end      
    end   
    
    def register_stem(name, arity, key)
      return if @name_to_id[name]
      @id_to_name[@curid] = name
      @name_to_id[name] = @curid
      (@stems[@curid] ||= []) << Stem.new(name,arity,key,self) do |item|
        self.route(item)
      end
      @curid += 1
    end
    
    def flush
      found = true
      while found
        found = false
        @input_bufs.each do |id, buf| 
          if buf.length > 0
            found = true
            flush_buf(buf, @inputs[id])
          end
        end
      end
    end
          
      
    def flush_buf(buf, source)
      source_id = name_to_id[source.name]
      itemset = EddyItemSet.new(buf, source.name, source_id, @stems)
      @input_bufs[source_id] = []
      # puts "created EddyItem #{item.inspect}"
      # and route
      route(itemset)
    end
    
    def insert(item, source) 
      # convert inbound singleton into outbound format
      source_id = name_to_id[source.name]
      newitem = Array.new(@inputs.length)
      newitem[source_id] = item
      buf = @input_bufs[source_id]
      buf << newitem
      if (item.length >= BUFSIZE)
        flush_buf(buf, source)
      end
    end
    
    def choose_route(itemset)
      # route to self first
       # selfbit = 2**@name_to_id[item.source_name]
       # n = nil
       # if item.ready & selfbit != 0
       #   n = @stems[item.source_name][0]
       #   raise "n is nil, #{@id_to_name[i]}" if n.nil?
       #   return n
       # end

       # here's where the interesting routing should go
       # but for now all we'll do is find the first stem that's ready
       n = nil
       i = Crocus.highest_bit(itemset.ready)
       raise "out of readies" if i < 0
       n = @stems[i][0]
       # @ids.each do |i| 
       #   if itemset.ready & 2**i != 0
       #     n = @stems[i][0]
       #     raise "n is nil, #{@id_to_name[i]}" if n.nil?
       #     break
       #   end
       # end
       return n
    end
    
    def route(itemset)
      return if itemset.nil?
      # raise "item from unknown source #{itemset.source_name}" if @name_to_id[itemset.source_name].nil?
      # puts "item.done = #{item.done}, @inputs.length = #{@inputs.length}"
      if itemset.done == @all_on
        raise "orphaned stuff in ready: #{itemset.ready.inspect}" unless itemset.ready == 0
        itemset.items.each {|item| @blk.call(item)}
        return 
      end
      # puts "routing #{item.item.inspect} from #{item.source_name}"
      
      # if nothing's ready, must be time to cross-product with something
      itemset.ready = @all_on - itemset.done if itemset.ready == 0
      # choose dest
      n = choose_route(itemset)
      preds = id_to_preds[n.my_id] 
      if itemset.source_id != n.my_id
        key_cols = preds.first[1] unless preds.nil? # so far we only handle on a single join pred!
        # key = key_cols.nil? ? [] : key.map{|i| item.item[item.source_id][i]}
        # puts "routing #{item.item.inspect} from #{item.source_name} to Stem #{n.name} with lookup key #{key_cols}"
      else
        key_cols = n.key
        # key = key_cols.map{|i| item.item[item.source_id][i]}
        # puts "routing #{item.item.inspect} from #{item.source_name} to Stem #{n.name} with insert key #{key_cols}"
      end

      # flip the bits to what they should be AFTER this insert
      itemset.ready -= n.my_bit
      unless preds.nil?
        preds.each {|i| itemset.ready += i[0] if (itemset.ready & i[0] == 0) and (itemset.done & i[0] == 0)}
      end
      itemset.done += n.my_bit 
              
      key_cols = nil if key_cols == []
      n.insert(itemset, key_cols)
    end
  end
end