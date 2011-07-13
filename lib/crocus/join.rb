require 'crocus/elements'

class Crocus
  class PushSHJoin < PushElement
    def initialize(name, arity, sources_in, keys_in, &blk)
      super(name, arity, *sources_in, &blk)
      @items = [{}, {}]
      @source_names = sources_in.map{|s| s.name}
      @keys = keys_in
    end
  
    def insert(item, source)
      offset = (@source_names[0] == source.name) ? 0 : ((@source_names[1] == source.name) ? 1 : nil)
      raise "item #{item} inserted into join from unknown source #{source.name}" if offset.nil?
      key = @keys[offset].map{|k| item[k]}
      #build
      # puts "building #{item} into @source[#{offset}] on key #{key}"
      (@items[offset][key] ||= []) << item
      #and probe
      # puts "probing #{item} into @source[#{1-offset}] on key #{key}"
      matches = @items[1-offset][key]
      matches.each do |m|
        # puts "    found match #{m}"
        result = [nil,nil]
        result[offset] = item
        result[1-offset] = m
        @blk.call(result.flatten)
      end unless matches.nil?
    end
  end
end