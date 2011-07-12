require 'crocus/elements'

BUFSIZE = 1000

class Crocus
  class EddyItemSet
    # and ItemSet is a set of (possibly partially empty) result tuple-arrays, which
    # share the same sources and ready/done status
    attr_accessor :items, :ready, :done, :source_name, :source_id, :stem_mask
    def initialize(itemset_in, source_name_in, source_id_in, matching_stems)
      @items = itemset_in
      @source_name = source_name_in
      @source_id = source_id_in
      @ready = 0
      # ready to route to matching stems
      matching_stems.each do |stem|
        @ready += 2**stem.my_id
      end
      @stem_mask = @ready
      @done = 0
    end
    def each
      @items.each
    end
  end
  
  class Stem < PushElement
    attr_reader :insert_key, :lookup_key, :my_id, :my_bit
    def initialize(name, my_id_in, source_id_in, arity, insert_key_in, lookup_key_in, eddy, &blk)
      @items = {}
      @insert_key = insert_key_in
      @lookup_key = lookup_key_in
      @eddy = eddy
      @my_id = my_id_in
      @my_bit = 2**@my_id
      @source_id = source_id_in
      super(name, arity, [], &blk)
    end
    
    def insert(itemset)      
      if itemset.source_name == @name
        # insert into itemset and call @blk
        # puts "inserting #{item.item.inspect} into Stem #{@name}"
        # key = @key.map{|i| item.item[item.source_id][i]}
        itemset.items.each do |item|
          subitem = item[itemset.source_id]
          # key = key_cols.map{|i| subitem[i]}          
          key = insert_key.nil? ? [] : [subitem[insert_key[0]]]
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
          key = lookup_key.nil? ? [] : [subitem[lookup_key[0]]]
          matches = @items[key]
          unless matches.nil?
            matches.each do |i|
              if item[@source_id].nil?
                # time to fill in this part of the output tuple
                newitem = item.clone
                newitem[@source_id] = i
              else
                # this match is not the one that was filled into this output tuple
                next if item[@source_id] != i
                newitem = item
              end
              newitems << newitem unless newitem.nil?
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
    attr_reader :name_to_source_id, :all_on, :init_ready, :stem_id_to_pair_bit
    attr_accessor :curid
    # innies is an array of PushElements that push back to the Eddy
    # preds is an array of attribute pairs of the form [[push_elem, key], [push_elem, key]]
    def initialize(innies, preds, &blk)
      @elements = []
      @inputs = innies
      @preds = preds
      @stems = []
      @source_id_to_stems = {}
      @name_to_source_id = {}
      @cur_source_id = 0
      @blk = blk
      @stem_id_to_pair_bit = {}
      @ids = (0..@inputs.length-1) # precompute this outside the insert path!
      @all_on = 0
      
      counts = @inputs.reduce({}) do |memo,i|
        memo[i.name] ||= 0
        memo[i.name] += 1
        memo
      end
      counts = counts.map{|k,v| k if v > 1}.compact
      raise "duplicated input names #{counts.inspect} in Eddy initializer" if counts.length > 0
      
      @input_bufs = {}
      inputs_left = {}
      @inputs.each_with_index do |inp, i| 
        # set up a buffer for each input
        @input_bufs[i] = []     
        # set self.route to be the continuation blk for each input
        inp.set_block { |item| self.insert(item, inp) }
        # keep track of the inputs we haven't made a stem for yet
        (inputs_left[inp.name] ||= []) << inp
      end
      
      # for each pred, make sure we have an appropriately-keyed stem
      @preds.each do |l, r|
        l_id = register_stem(l[0].name, l[0].arity, l[1], r[1])
        inputs_left[l[0].name].pop
        r_id = register_stem(r[0].name, r[0].arity, r[1], l[1])
        inputs_left[r[0].name].pop
        stem_id_to_pair_bit[l_id] = 2**r_id
        stem_id_to_pair_bit[r_id] = 2**l_id
      end
      
      # any inputs that are left will have a stem that we'll need to scan
      inputs_left.each do |k,v|
        v.each do |i|
          register_stem(i.name, i.arity, nil, nil) # empty key will hash all entries together on nil
        end
      end      
    end   
    
    def register_stem(name, arity, insert_key, lookup_key)
      # XXX Check for redunant Stems?
      # return if @name_to_id[name]
      source_id = (@name_to_source_id[name] ||= @cur_source_id)
      @cur_source_id += 1 if source_id == @cur_source_id
      stem_id = @stems.length
      # puts "registering Stem #{stem_id} for #{name}[#{insert_key}]"
      newstem = Stem.new(name,stem_id,source_id,arity,insert_key,lookup_key,self) do |item|
        self.route(item)
      end
      @stems << newstem
      (@source_id_to_stems[source_id] ||= []) << newstem
      @all_on += 2**stem_id
      return stem_id
    end
    
    def flush
      found = true
      while found
        found = false
        @input_bufs.each do |id, buf| 
          if buf.length > 0
            found = true
            flush_buf(buf, @inputs[id], id)
          end
        end
      end
    end
          
      
    def flush_buf(buf, source, source_id)
      itemset = EddyItemSet.new(buf, source.name, source_id, @source_id_to_stems[source_id])
      @input_bufs[source_id] = []
      # puts "created EddyItem #{item.inspect}"
      # and route
      route(itemset)
    end
    
    def insert(item, source) 
      # handle inbound singletons: convert into outbound format and batch
      source_id = @name_to_source_id[source.name]
      newitem = Array.new(@inputs.length)
      newitem[source_id] = item
      buf = (@input_bufs[source_id] ||= [])
      buf << newitem
      if (buf.length >= BUFSIZE)
        flush_buf(buf, source, source_id)
      end
    end
    
    def choose_route(itemset)
      n = nil
      # always route to a self-stem if there is one
      matches = itemset.ready & itemset.stem_mask
      i = Crocus.highest_bit(matches)
      if (i < 0)
        # no self-routes.
        # here's where the interesting routing should go
        # but for now all we'll do is find the first stem that's ready
        i = Crocus.highest_bit(itemset.ready)
      end
      raise "out of readies" if i < 0
      n = @stems[i]
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
      return if itemset.nil? or itemset.items == []
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
      # flip the bits to what they should be AFTER this insert
      itemset.ready -= n.my_bit
      pair_bit = stem_id_to_pair_bit[n.my_id]
      unless pair_bit.nil?
        itemset.ready += pair_bit if (itemset.ready & pair_bit == 0) and (itemset.done & pair_bit == 0)
      end
      itemset.done += n.my_bit 
              
      # puts "routing itemset #{itemset.items.inspect}from #{itemset.source_name} to stem [#{n.name}(#{n.insert_key})]"
      n.insert(itemset)
    end
  end
end