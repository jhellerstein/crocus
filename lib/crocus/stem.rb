require 'crocus/bits'
require 'crocus/elements'
class Crocus
  class Stem < PushElement
    attr_reader :insert_key, :lookup_key, :eddy_element_id, :eddy_element_bit
    def initialize(name, eddy_element_id_in, source_id_in, arity, insert_key_in, lookup_key_in, eddy, &blk)
      @items = {}
      @insert_key = insert_key_in
      @lookup_key = lookup_key_in
      @eddy = eddy
      @eddy_element_id = eddy_element_id_in
      @eddy_element_bit = 2**@eddy_element_id
      @source_id = source_id_in
      super(name, arity, &blk)
    end
  
    def insert(itemset, source)      
      if itemset.source_name == @name
        # insert into itemset and call @blk
        # puts "inserting #{item.item.inspect} into Stem #{@name}"
        itemset.items.each do |item|
          subitem = item[itemset.source_id]
          key = insert_key.nil? ? [] : insert_key.map{|i| subitem[i]} 
          (@items[key] ||= []) << subitem
        end
        @blk.call(itemset)
      else
        # find matches and route resulting concatenation via calling @blk
        # puts "looking for key #{key.inspect} in #{@name}"
        newitems = []
        itemset.items.each do |item|
          subitem = item[itemset.source_id]
          key = lookup_key.nil? ? [] : lookup_key.map{|i| subitem[i]}
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
        itemset.source_id = -1
        @blk.call(itemset)
      end
    end
    def local_end(source)
      @items = {}
      return true
    end
  end
  
  class PushStemEddy < PushEddy
    attr_reader :stem_id_to_pair_bit
    def construct_elements
      @elements = []
      @source_id_to_elements = {}
      @stem_id_to_pair_bit = {}
      inputs_left = {}
      @inputs.map{|inp| (inputs_left[inp.name] ||= []) << inp }
      
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
      source_id = @name_to_source_id[name]
      stem_id = @elements.length
      # puts "registering Stem #{stem_id} for #{name}[#{insert_key}]"
      newstem = Stem.new(name,stem_id,source_id,arity,insert_key,lookup_key,self) do |item|
        self.route(item)
      end
      @elements << newstem
      (@source_id_to_elements[source_id] ||= []) << newstem
      return stem_id
    end
    
    def choose_route(itemset)
      n = nil
      # always route to a self-stem if there is one
      matches = itemset.ready & itemset.element_mask
      i = Crocus.highest_bit(matches)
      if (i < 0)
        # no self-routes.
        # here's where the interesting routing should go
        # but for now all we'll do is find the first stem that's ready
        i = Crocus.highest_bit(itemset.ready)
      end
      raise "out of readies" if i < 0
      n = @elements[i]
      # flip the bits to what they should be AFTER this insert
      itemset.ready -= n.eddy_element_bit
      pair_bit = stem_id_to_pair_bit[n.eddy_element_id]
      unless pair_bit.nil?
        itemset.ready += pair_bit if (itemset.ready & pair_bit == 0) and (itemset.done & pair_bit == 0)
      end
      itemset.done += n.eddy_element_bit 
      return n
    end    
  end
end