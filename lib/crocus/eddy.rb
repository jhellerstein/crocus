require 'crocus/elements'
require 'set'

class Crocus
  class EddyItemSet
    # an EddyItemSet is a set of (possibly partially empty) result tuple-arrays, which
    # share the same sources and ready/done status
    attr_accessor :items, :ready, :done, :source_name, :source_id, :element_mask
    def initialize(itemset_in, source_name_in, source_id_in, matching_elements)
      @items = itemset_in
      @source_name = source_name_in
      @source_id = source_id_in
      @ready = 0
      # ready to route to matching elements
      matching_elements.each do |element|
        @ready += 2**element.eddy_element_id
      end
      @element_mask = @ready
      @done = 0
    end
    def each
      @items.each
    end
  end

  class PushEddy < PushElement
    attr_reader :name_to_source_id, :all_on, :init_ready, :input_bufs, :inputs
    attr_accessor :curid
    # innies is an array of PushElements that push back to the Eddy
    # preds is an array of attribute pairs of the form [[push_elem, key], [push_elem, key]]
    def initialize(name, arity, inputs, preds, &blk)
      super(name, arity, &blk)  
      @inputs = inputs 
      @preds = preds
      @elements = []
      @name_to_source_id = {}
      @ids = (0..@inputs.length-1) # precompute this outside the insert path!
      @all_on = 0
      @sources_ended = Set.new
      @source_id_to_elements = {}

      inputs.each_with_index {|inp,i| @name_to_source_id[inp.name] = i}
        
      counts = @inputs.reduce({}) do |memo,i|
        memo[i.name] ||= 0
        memo[i.name] += 1
        memo
      end
      counts = counts.map{|k,v| k if v > 1}.compact
      raise "duplicated input names #{counts.inspect} in Eddy initializer" if counts.length > 0

      @input_bufs = {}
      # set up a buffer for each input
      (0..@inputs.length-1).each {|i| input_bufs[i] = []}
      construct_elements
      (0..@elements.length-1).each{|i| @all_on += 2**i}
    end
    
    def initial_ready_elements(source_id)
      @source_id_to_elements[source_id]
    end

    def local_flush
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
      itemset = EddyItemSet.new(buf, source.name, source_id, initial_ready_elements(source_id))
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

    def route(itemset)
      return if itemset.nil? or itemset.items == []
      # raise "item from unknown source #{itemset.source_name}" if @name_to_id[itemset.source_name].nil?
      # puts "item.done = #{item.done}, @inputs.length = #{@inputs.length}"
      if itemset.done == @all_on
        raise "orphaned stuff in ready: #{itemset.ready.inspect}" unless itemset.ready == 0
        itemset.items.each {|item| @blk.call(item.flatten)}
        return 
      end
      # puts "routing #{item.item.inspect} from #{item.source_name}"

      # if nothing's ready, must be time to cross-product with something
      itemset.ready = @all_on - itemset.done if itemset.ready == 0
      # choose dest
      n = choose_route(itemset)              
      # puts "routing itemset #{itemset.items.inspect}from #{itemset.source_name} to element #{n.name}"
      n.insert(itemset, self)
    end

    def local_end(source)
      @sources_ended.add source
      if @sources_ended.size == @inputs.size
        local_flush
        @elements.each {|s| s.end(self)}
        return true
      else
        return false
      end
    end  
    # these need to be defined in a subclass
    # def construct_elements
    # end
    # def choose_route
    # end
  end  
end