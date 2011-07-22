require 'crocus/elements'
require 'set'

class Crocus
  class PushSHJoin < PushElement
    def initialize(name, arity, sources_in, keys_in, &blk)
      super(name, arity, &blk)
      @items = [{}, {}]
      @source_names = sources_in.map{|s| s.name}
      @input_bufs = [[],[]]
      @keys = keys_in
      @sources_ended = Set.new
    end
    
    def set_keys(keys_in)
      @keys = keys_in
      return self
    end
    
    def insert(item, source)
      offset = (@source_names[0] == source.name) ? 0 : ((@source_names[1] == source.name) ? 1 : nil)
      raise "item #{item} inserted into join from unknown source #{source.name}" if offset.nil?
      buf = @input_bufs[offset]
      buf << item
      if (buf.length >= BUFSIZE)
        flush_buf(buf, offset)
      end
    end
    
    def insert_item(item, offset)
      key = (@keys.nil? or @keys == []) ? nil : @keys[offset].map{|k| item[k]}
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
        push_out(result)
      end unless matches.nil?
    end
    
    def flush_buf(buf, offset)
      buf.each do |item|
        insert_item(item, offset)
      end
      @input_bufs[offset] = []
    end
    def local_flush
      @input_bufs.each_with_index do |buf, offset| 
        flush_buf(buf,offset) if buf.length > 0
      end
    end
    def local_end(source)
      @sources_ended << source
      if @sources_ended.size == 2
        local_flush
        @items = [{},{}]
        return true
      else
        return false
      end
    end
  end
end