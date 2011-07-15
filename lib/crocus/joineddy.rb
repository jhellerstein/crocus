require 'crocus/bits'
require 'crocus/elements'
require 'crocus/stem'
class Crocus  
  class PushEddyJoinInShim < PushElement
    attr_accessor :eddy_element_id, :eddy_element_bit, :source, :source_id
    def initialize(name, arity, source, eddy_element_id_in, source_id_in)
      super(name, arity)
      @eddy_element_id = eddy_element_id_in
      @eddy_element_bit = 2**@eddy_element_id
      @source = source
      @source_id = source_id_in
    end
  end
  
  # wrap a symmetric-hash join with EddyItemSet handling
  class PushEddySHJoin < PushSHJoin
    def initialize(name, arity, sources_in, keys_in, pred_in, eddy_in, &blk)
      # output block is always absorb_output, which assembles the output content
      raise "can't set block on a PushEddySHJoin" unless blk.nil?
      super(name, arity, sources_in, keys_in)
      set_block {|i| absorb_output(i)}
      @output_buf = []
      @eddy = eddy_in
      @pred = pred_in
      @source_ids = sources_in.map{|s| s.source_id}
      @source_names = sources_in.map{|i| i.name}
    end
    
    def insert_item(item, offset)
      output_offset = @source_ids[offset]
      other_output_offset = @source_ids[1-offset]
      key = @keys[offset].map{|k| item[output_offset][k]}
      #build
      # puts "building #{item} into @source[#{offset}] on key #{key}"
      (@items[offset][key] ||= []) << item
      #and probe
      # puts "probing #{item} into @source[#{1-offset}] on key #{key}"
      matches = @items[1-offset][key]      
      matches.each do |m|
        # puts "    found match #{m}"
        newitem = item.clone
        (0..newitem.length-1).each do |i|
          newitem[i]=m[i] if newitem[i].nil? and not m[i].nil?
        end
        @blk.call(newitem)
      end unless matches.nil?
    end

    # we get a sizable EddyItemSet at insert time
    def insert(itemset, source)
      first = itemset.items.first
      offset = @source_names.index(source.name.flatten)
      @current_itemset = itemset
      unless first[@source_ids[1-offset]].nil?
        # this join has already been done!  our job is just to check pred
        check_pred(itemset)
      else
        # do SH-join processing
        itemset.items.each do |i| 
          insert_item(i, offset)
        end
      end
      # now output the results of this batch
      flush_output
    end

    # buffer output until it's big enough
    def absorb_output(item)
      @output_buf << item
    end
   
    def check_pred(itemset)
      @output_buf += itemset.items.find_all do |item|
        # because shims wrap source names in array brackets,
        # need to do same here when calling Array#index
        l_item = item[@source_names.index([@pred[0][0].name])]
        r_item = item[@source_names.index([@pred[1][0].name])]
        result = (@pred[0][1].map{|o| l_item[o]} == @pred[1][1].map{|o| r_item[o]})
      end
      flush_output
    end

    # processing continues with the eddy router
    def flush_output
      if @output_buf.size > 0
        @current_itemset.items = @output_buf
        @output_buf = []
        @eddy.route(@current_itemset)
      else
        @eddy.route(nil) 
      end
    end
    
    # no input bufs, only output bufs
    def local_flush
      flush_output
    end      
  end
  
  
  # XXX We route based on INPUT itemset bits.
  # XXX But different matches may have come from itemsets with different bits!
  class PushJoinEddy < PushEddy
    attr_reader :shim_id_to_pair_bit
    
    def construct_elements
      @shim_id_to_pair_bit = {}
      inputs_handled = Set.new
      @name_to_input = {}
      @inputs.map{|inp| @name_to_input[inp.name] = inp}
      
      # for each pred, make sure we have an appropriately-keyed join
      @preds.each do |l, r|
        register_pred(l,r)
        inputs_handled.merge [l[0],r[0]]
      end
      
      # any inputs not handled so far get joined to the first input on a nil key
      # if no inputs have been handled, skip this for first input
      (@inputs-inputs_handled.to_a).each do |i|
        first = (inputs_handled.size == 0) ? @inputs.first : inputs_handled.first
        next if i == first
        l = [first, []]
        r = [i, []]
        register_pred(l,r)
      end 
    end   
    
    def register_pred(l,r)
      join_name = 'eddy_'+l[0].name+'_'+r[0].name
      # puts "constructing element #{join_name}"

      left_shim = register_shim(@name_to_input[l[0].name], join_name)
      right_shim = register_shim(@name_to_input[r[0].name], join_name)
      arity = left_shim.source.arity+right_shim.source.arity
      
      join = Crocus::PushEddySHJoin.new(join_name, arity, [left_shim,right_shim], [l[1],r[1]], [l,r], self)
      left_shim.wire_to(join)
      right_shim.wire_to(join)
      shim_id_to_pair_bit[left_shim.eddy_element_id] = right_shim.eddy_element_bit
      shim_id_to_pair_bit[right_shim.eddy_element_id] = left_shim.eddy_element_bit
    end
    
    def register_shim(source, join_name)
      source_id = @name_to_source_id[source.name]
      # we wrap source name in brackets to distinguish shim from source
      shim_name = [source.name]
      shim = Crocus::PushEddyJoinInShim.new(shim_name, source.arity, source, @elements.length, source_id)
      @elements << shim
      (@source_id_to_elements[source_id] ||= []) << shim
      return shim
    end
    
    def choose_route(itemset)
      n = nil
      # here's where the interesting routing should go
      # but for now all we'll do is find the first element that's ready
      i = Crocus.highest_bit(itemset.ready)
      raise "out of readies" if i < 0
      n = @elements[i]
      # flip the bits to what they should be AFTER this insert
      pair_bit = shim_id_to_pair_bit[n.eddy_element_id]
      change_bits = n.eddy_element_bit
      change_bits |= pair_bit unless pair_bit.nil?
      itemset.done |= change_bits
      itemset.ready &= (@all_on - change_bits)
      return n
    end    
  end
end