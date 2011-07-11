require 'crocus/elements'

class Blossom
  class EddyItem
    attr_accessor :item, :ready, :done, :source_name, :source_id
    def initialize(item_in, source_name_in, source_id_in, stems_in)
      @item = item_in
      @source_name = source_name_in
      @source_id = source_id_in
      @ready = 2**source_id_in # ready to route to self
      # puts "@all_on = #{@all_on}"
      @done = 0
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
    
    def insert(item, key)      
      if item.source_name == @name
        # insert into itemset and call @blk
        # puts "inserting #{item.item.inspect} into Stem #{@name}"
        # key = @key.map{|i| item.item[item.source_id][i]}
        @items[key] ||= []
        @items[key] << [item.item[@my_id]] 
        @blk.call(item)
      else
        # find matches and route resulting concatenation via calling @blk
        # puts "looking for key #{key.inspect} in #{@name}"
        matches = @items[key]
        if matches.nil?
          # puts "no matches for key #{key.inspect} in #{@name}"
          @blk.call(nil)
        else 
          # origitemitem = item.item[@my_id].clone
          matches.each do |i|
            item.item.delete_at @my_id
            item.item.insert(@my_id,i.flatten)
            @blk.call(item)
          end
        end 
      end
    end
      
    def <<(i)
      insert(i)
    end
  end

  class PushEddy < PushElement
    attr_reader :id_to_name, :name_to_id, :all_on, :init_ready, :name_to_preds
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
      @name_to_preds = {}
      
      counts = @inputs.reduce({}) do |memo,i|
        memo[i.name] ||= 0
        memo[i.name] += 1
        memo
      end
      counts = counts.map{|k,v| k if v > 1}.compact
      raise "duplicated input names #{counts.inspect} in Eddy initializer" if counts.length > 0
      
      # set self.route to be the continuation blk for each input
      @inputs.each { |i| i.set_block { |item| self.insert(item, i) } }
      
      # keep track of the inputs we haven't made a stem for yet
      inputs_left = {}
      @inputs.each do |i| 
        inputs_left[i.name] ||= []
        inputs_left[i.name] << i
      end
      
      # for each pred, make sure we have an appropriately-keyed stem
      @preds.each do |l, r|
        register_stem(l[0].name, l[0].arity, l[1])
        inputs_left[l[0].name].pop
        register_stem(r[0].name, r[0].arity, r[1])
        inputs_left[r[0].name].pop
        name_to_preds[l[0].name] ||= []
        name_to_preds[l[0].name] << [2**name_to_id[r[0].name], r[1]]
        name_to_preds[r[0].name] ||= []
        name_to_preds[r[0].name] << [2**name_to_id[l[0].name], l[1]]
      end
      
      # any inputs that are left will have a stem that we'll need to scan
      inputs_left.each do |k,v|
        v.each do |i|
          register_stem(i.name, i.arity, []) # empty key will hash all entries together on nil
        end
      end      
      (0..@stems.length-1).each {|i| @all_on ||= 0; @all_on += 2**i}
    end   
    
    def register_stem(name, arity, key)
      return if @name_to_id[name]
      @id_to_name[@curid] = name
      @name_to_id[name] = @curid
      @stems[name] ||= []
      @stems[name] << Stem.new(name,arity,key,self) do |item|
        self.route(item)
      end
      @curid += 1
    end
      
    def insert(item, source) 
      # convert inbound singleton into outbound format
      item = @inputs.map.with_index{|inp, i| source.name == id_to_name[i] ? item : []}
      item = EddyItem.new(item, source.name, name_to_id[source.name], @stems)
      # puts "created EddyItem #{item.inspect}"
      # and route
      route(item)
    end
    
    def choose_route(item)
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
       (0..@id_to_name.length-1).each do |i| 
         if item.ready & 2**i != 0
           n = @stems[@id_to_name[i]][0]
           raise "n is nil, #{@id_to_name[i]}" if n.nil?
           break
         end
       end
       return n
    end
    
    def route(item)
      return if item.nil?
      raise "item from unknown source #{item.source_name}" if @name_to_id[item.source_name].nil?
      # puts "item.done = #{item.done}, @inputs.length = #{@inputs.length}"
      if item.done == @all_on
        raise "orphaned stuff in ready: #{item.ready.inspect}" unless item.ready == 0
        return @blk.call(item.item)
      end
      # puts "routing #{item.item.inspect} from #{item.source_name}"
      
      # if nothing's ready, must be time to cross-product with something
      item.ready = @all_on - item.done if item.ready == 0
      # choose dest
      n = choose_route(item)
      if item.source_id != n.my_id
        entry = @name_to_preds[n.name]
        key = entry.first[1] unless entry.nil? # so far we only handle on a single join pred!
        key = key.nil? ? [] : key.map{|i| item.item[item.source_id][i]}
        # puts "routing #{item.item.inspect} from #{item.source_name} to Stem #{n.name} with lookup key #{key}"
      else
        key = n.key.map{|i| item.item[item.source_id][i]}
        # puts "routing #{item.item.inspect} from #{item.source_name} to Stem #{n.name} with insert key #{key}"
      end

      # flip the bits to what they should be AFTER this insert
      preds = name_to_preds[n.name] 
      item.ready -= n.my_bit
      unless preds.nil?
        preds.each {|i| item.ready += i[0] if (item.ready & i[0] == 0) and (item.done & i[0] == 0)}
      end
      item.done += n.my_bit 
              
      n.insert(item, key)
    end
  end
end