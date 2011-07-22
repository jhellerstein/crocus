require 'msgpack'
require 'superators'

class Crocus
  ########
  #--
  # the collection types
  # each collection is partitioned into 4:
  # - pending holds tuples deferred til the next tick
  # - storage holds the "normal" tuples
  # - delta holds the delta for rhs's of rules during semi-naive
  # - new_delta will hold the lhs tuples currently being produced during s-n
  #++

  class Collection
    include Enumerable

    attr_accessor :crocus_instance, :locspec_idx # :nodoc: all
    attr_reader :schema, :tabname # :nodoc: all
    attr_reader :storage, :delta, :new_delta, :pending # :nodoc: all

    #############
    ## Begin INIT
    #############
    def initialize(name, crocus_instance, given_schema=nil, defer_schema=false) # :nodoc: all
      @tabname = name
      @crocus_instance = crocus_instance
      init_schema(given_schema) unless given_schema.nil? and defer_schema
      init_buffers
    end

    private
    def init_buffers
      init_storage
      init_pending
      init_deltas
    end
    
    private
    def init_storage;@storage = {};end

    private
    def init_pending;@pending = {};end

    private
    def init_deltas;@delta = {};@new_delta = {};end

    private
    def init_schema(given_schema)
      given_schema ||= {[:key]=>[:val]}
      @given_schema = given_schema
      @schema, @key_cols = parse_schema(given_schema)
      @key_colnums = key_cols.map {|k| schema.index(k)}
      setup_accessors
    end

    # The user-specified schema might come in two forms: a hash of Array =>
    # Array (key_cols => remaining columns), or simply an Array of columns (if no
    # key_cols were specified). Return a pair: [list of columns in entire tuple,
    # list of key columns]
    private
    def parse_schema(given_schema)
      if given_schema.respond_to? :keys
        raise "invalid schema for #{tabname}" if given_schema.length != 1
        key_cols = given_schema.keys.first
        val_cols = given_schema.values.first
      else
        key_cols = given_schema
        val_cols = []
      end

      schema = key_cols + val_cols
      schema.each do |s|
        if s.class != Symbol
          raise "Invalid schema element \"#{s}\", type \"#{s.class}\""
        end
      end
      if schema.uniq.length < schema.length
        raise "schema for #{tabname} contains duplicate names"
      end

      return [schema, key_cols]
    end

    public
    def clone_empty #:nodoc: all
      self.class.new(tabname, crocus_instance, @given_schema)
    end

    # subset of the schema (i.e. an array of attribute names) that forms the key
    public
    def key_cols
      @key_cols
    end

    # subset of the schema (i.e. an array of attribute names) that is not in the key
    public
    def val_cols # :nodoc: all
      schema - key_cols
    end

    # define methods to turn 'table.col' into a [table,col] pair
    # e.g. to support something like
    #    j = join link, path, {link.to => path.from}
    private
    def setup_accessors
      s = @schema
      s.each do |colname|
        reserved = eval "defined?(#{colname})"
        unless (reserved.nil? or
          (reserved == "method" and method(colname).arity == -1 and (eval(colname))[0] == self.tabname))
          raise "symbol :#{colname} reserved, cannot be used as column name for #{tabname}"
        end
      end

      # set up schema accessors, which are class methods
      m = Module.new do
        s.each_with_index do |c, i|
          define_method c do
            [@tabname, i, c]
          end
        end
      end
      self.extend m

      # now set up a Module for tuple accessors, which are instance methods
      @tupaccess = Module.new do
        s.each_with_index do |colname, offset|
          define_method colname do
            self[offset]
          end
        end
      end
    end

    # define methods to access tuple attributes by column name
    private
    def tuple_accessors(tup)
      tup.extend @tupaccess
    end
    
    #############
    ## End INIT
    #############
    
    ###############
    ## Begin Access
    ###############
    # generate a tuple with the schema of this collection and nil values in each attribute
    public
    def null_tuple
      tuple_accessors(Array.new(@schema.length))
    end

    # project the collection to its key attributes
    public
    def keys
      map{|t| @key_colnums.map {|i| t[i]}}
    end

    # project the collection to its non-key attributes
    public
    def values
      map { |t| (self.key_cols.length..self.schema.length-1).map{|i| t[i]} }
    end

    # map each item in the collection into a string, suitable for placement in stdio
    public
    def inspected
      map{|t| [t.inspect]}
    end

    public
    def to_push_elem
      # if no push source yet, set one up
      unless @crocus_instance.scanners[tabname]
        @crocus_instance.scanners[tabname] = Crocus::ScannerElement.new(tabname, schema.length, self)
        @crocus_instance.sources[tabname] = @crocus_instance.scanners[tabname]
      end
      @crocus_instance.sources[tabname]
    end

    # akin to map, but modified for efficiency in Bloom statements
    public
    def pro(&blk)
      # set up a pro on the matching push source
      pusher = to_push_elem.pro
      pusher.set_block(&blk) if blk
    end
    
    public
    def join(elem2, &blk)
      the_pro = to_push_elem
      the_pro.join(elem2, &blk)
    end

    public
    def *(elem2, &blk)
      join(elem2, &blk)
    end

    # By default, all tuples in any rhs are in storage or delta. Tuples in
    # new_delta will get transitioned to delta in the next iteration of the
    # evaluator (but within the current time tick).
    public
    def each(&block) # :nodoc: all
      each_from([@storage, @delta], &block)
    end

    private
    def each_from(bufs, &block) # :nodoc: all
      bufs.each do |b|
        b.each_value do |v|
          tick_metrics if crocus_instance and crocus_instance.options[:metrics]
          yield v
        end
      end
    end

    public
    def each_from_sym(buf_syms, &block) # :nodoc: all
      bufs = buf_syms.map do |s|
        case s
        when :storage then @storage
        when :delta then @delta
        when :new_delta then @new_delta
        else raise "bad symbol passed into each_from_sym"
        end
      end
      each_from(bufs, &block)
    end

    # return item with key +k+
    public
    def [](k)
      # assumes that key is in storage or delta, but not both
      # is this enforced in do_insert?
      t = @storage[k]
      return t.nil? ? @delta[k] : t
    end
    
    public
    def close # :nodoc: all
    end
    
    ###############
    ## END Access
    ###############
    


    ##############
    ## BEGIN preds
    ##############
    # checks for key +k+ in the key columns
    public
    def has_key?(k)
      check_enumerable(k)
      return false if k.nil? or self[k].nil?
      return true
    end

    # checks for +item+ in the collection
    public
    def include?(item)
      return true if key_cols.nil? or (key_cols.empty? and length > 0)
      return false if item.nil? or item.empty?
      key = @key_colnums.map{|i| item[i]}
      return (item == self[key])
    end

    # checks for an item for which +block+ produces a match
    public
    def exists?(&block)
      if length == 0
        return false
      elsif not block_given?
        return true
      else
        return ((detect{|t| yield t}).nil?) ? false : true
      end
    end
    
    private
    def include_any_buf?(t, key_vals)
      bufs = [self, @delta, @new_delta]
      bufs.each do |b|
        old = b[key_vals]
        next if old.nil?
        if old != t
          raise_pk_error(t, old)
        else
          return true
        end
      end
      return false
    end
    ##############
    ## END preds
    ##############

    ###############
    ## Begin Update
    ###############
    private
    def raise_pk_error(new_guy, old)
      keycols = @key_colnums.map{|i| old[i]}
      raise "Key conflict inserting #{new_guy.inspect} into \"#{tabname}\": existing tuple #{old.inspect}, key_cols = #{keycols.inspect}"
    end

    private
    def prep_tuple(o)
      unless o.respond_to?(:length) and o.respond_to?(:[])
        raise "non-indexable type inserted into \"#{tabname}\": #{o.inspect}"
      end
      if o.class <= String
        raise "String value used as a fact inserted into \"#{tabname}\": #{o.inspect}"
      end

      if o.length < schema.length then
        # if this tuple has too few fields, pad with nil's
        old = o.clone
        (o.length..schema.length-1).each{|i| o << nil}
        # puts "in #{@tabname}, converted #{old.inspect} to #{o.inspect}"
      elsif o.length > schema.length then
        # if this tuple has more fields than usual, bundle up the
        # extras into an array
        o = (0..(schema.length - 1)).map{|c| o[c]} << (schema.length..(o.length - 1)).map{|c| o[c]}
      end
      return o
    end

    private
    def do_insert(o, store)
      return if o.nil? # silently ignore nils resulting from map predicates failing
      o = prep_tuple(o)
      keycols = @key_colnums.map{|i| o[i]}

      old = store[keycols]
      if old.nil?
        store[keycols] = tuple_accessors(o)
      else
        raise_pk_error(o, old) unless old == o
      end
    end

    public
    def insert(o) # :nodoc: all
      # puts "insert: #{o.inspect} into #{tabname}"
      do_insert(o, @storage)
    end

    # instantaneously place an individual item from rhs into collection on lhs
    def <<(item)
      insert(item)
    end

    private
    def check_enumerable(o)
      unless o.nil? or o.class < Enumerable
        raise "Collection #{tabname} expected Enumerable value, not #{o.inspect} (class = #{o.class})"
      end
    end

    # Assign self a schema, by hook or by crook.  If +o+ is schemaless *and*
    # empty, will leave @schema as is.
    private
    def establish_schema(o)
      # use o's schema if available
      deduce_schema(o)
      # else use arity of first non-nil tuple of o
      if @schema.nil?
        o.each do |t|
          next if t.nil?
          fit_schema(t.size)
          break
        end
      end
    end

    # Copy over the schema from +o+ if available
    private
    def deduce_schema(o)
      if @schema.nil? and o.class <= Crocus::Collection and not o.schema.nil?
        # must have been initialized with defer_schema==true.  take schema from rhs
        init_schema(o.schema)
      end
      # if nothing available, leave @schema unchanged
    end

    # manufacture schema of the form [:c0, :c1, ...] with width = +arity+
    private
    def fit_schema(arity)
      # rhs is schemaless.  create schema from first tuple merged
      init_schema((0..arity-1).map{|indx| ("c"+indx.to_s).to_sym})
    end

    public
    def merge(o, buf=@new_delta) # :nodoc: all
      unless o.nil?
        o = o.uniq.compact if o.respond_to?(:uniq)
        check_enumerable(o)
        establish_schema(o) if @schema.nil?

        # it's a pity that we are massaging the tuples that already exist in the head
        o.each do |t|
          next if t.nil? or t == []
          t = prep_tuple(t)
          key_vals = @key_colnums.map{|k| t[k]}
          buf[key_vals] = tuple_accessors(t) unless include_any_buf?(t, key_vals)
        end
      end
      return self
    end

    public
    # instantaneously merge items from collection +o+ into +buf+
    def <=(collection)
      merge(collection)
    end

    # buffer items to be merged atomically at end of this timestep
    public
    def pending_merge(o) # :nodoc: all
      check_enumerable(o)
      establish_schema(o) if @schema.nil?

      o.each {|i| do_insert(i, @pending)}
      return self
    end

    public
    superator "<+" do |o|
      pending_merge o
    end
    
    public
    superator "<+-" do |o|
      self <+ o
      self <- o.map do |t|
        unless t.nil?
          self[@key_colnums.map{|k| t[k]}]
        end
      end
    end
    
    public 
    superator "<-+" do |o|
      self <+- o
    end
    
    ###############
    ## END Update
    ###############
    
    ###############
    ## END Utils
    ###############
    
    # Called at the end of each timestep: prepare the collection for the next
    # timestep.
    public
    def tick  # :nodoc: all
      @storage = @pending
      @pending = {}
      raise "orphaned tuples in @delta for #{@tabname}" unless @delta.empty?
      raise "orphaned tuples in @new_delta for #{@tabname}" unless @new_delta.empty?
    end

    # move deltas to storage, and new_deltas to deltas.
    public
    def tick_deltas # :nodoc: all
      # assertion: intersect(@storage, @delta) == nil
      @storage.merge!(@delta)
      @delta = @new_delta
      @new_delta = {}
    end

    public
    def uniquify_tabname # :nodoc: all
      # just append current number of microseconds
      @tabname = (@tabname.to_s + Time.new.tv_usec.to_s).to_sym
    end
    
    private
    def method_missing(sym, *args, &block)
      @storage.send sym, *args, &block
    end
  end

  class Scratch < Collection # :nodoc: all
  end

  class Temp < Collection # :nodoc: all
  end

  class Table < Collection # :nodoc: all
    def initialize(name, crocus_instance, given_schema) # :nodoc: all
      super(name, crocus_instance, given_schema)
      @to_delete = []
    end

    public
    def tick #:nodoc: all
      @to_delete.each do |tuple|
        keycols = @key_colnums.map{|k| tuple[k]}
        if @storage[keycols] == tuple
          @storage.delete keycols
        end
      end
      @pending.each do |keycols, tuple|
        old = @storage[keycols]
        if old.nil?
          @storage[keycols] = tuple
        else
          raise_pk_error(tuple, old) unless tuple == old
        end
      end
      @to_delete = []
      @pending = {}
    end

    superator "<-" do |o|
      o.each do |t|
        next if t.nil?
        @to_delete << prep_tuple(t)
      end
    end
  end
end

module Enumerable
  public
  # monkeypatch to Enumerable to rename collections and their schemas
  def rename(new_tabname, new_schema=nil)
    budi = (respond_to?(:crocus_instance)) ? crocus_instance : nil
    if new_schema.nil? and respond_to?(:schema)
      new_schema = schema
    end
    scr = Crocus::Scratch.new(new_tabname.to_s, budi, new_schema)
    scr.uniquify_tabname
    scr.merge(self, scr.storage)
    scr
  end
end
