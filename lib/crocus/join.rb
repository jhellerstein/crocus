require 'crocus/elements'

class Crocus
  class ShJoin < PushElement
    def initialize(name, sources_in, keys_in, &blk)
      @items = [{}, {}]
      @sources = sources_in.map{|s| s.name}
      @keys = keys_in
      super(name, arity, [], &blk)
    end
  
    def insert(item, source)
      offset = (@sources[0] == source.name) ? 0 : ((@sources[1] == source.name) ? 1 : nil)
      raise "item #{item} inserted into join from unknown source #{source.name}" if offset.nil?
      key = @keys[offset].map{|k| item[k]}
      #build
      (@items[offset][key] ||= []) << item
      #and probe
      matches = @items[1-offset][key]
      matches.each do |m|
        result = [nil,nil]
        result[offset] = item
        result[1-offset] = m
        @blk.call(result)
      end unless matches.nil?
    end
  end
end