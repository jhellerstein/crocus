require 'rubygems'
require 'eventmachine'
require 'msgpack'
require 'crocus/eddy'
require 'crocus/elements'
require 'crocus/group'
require 'crocus/itemset'
require 'crocus/join'
require 'crocus/server'

class Crocus
  attr_accessor :ip, :port, :dsock, :sources
  def initialize(options={})
    @options = options.clone
    @ip = @options[:ip]
    @options[:port] ||= 0
    @options[:port] = @options[:port].to_i
    @sources = {}
    PushElement.reset_count
  end
  
  def register_source(s)
    (@sources ||= {})[s.name] = s
  end
  
  def run_bg
    start_reactor
    # Wait for server to start up before returning
    schedule_and_wait do
      start_server
    end
    # puts "server started at #{@ip}:#{@port}"
  end  
  
  # Schedule a block to be evaluated by EventMachine in the future, and
  # block until this has happened.
  def schedule_and_wait
    # If EM isn't running, just run the user's block immediately
    # XXX: not clear that this is the right behavior
    unless EventMachine::reactor_running?
      puts "reactor not running"
      yield
      return
    end

    q = Queue.new
    EventMachine::schedule do
      ret = false
      begin
        yield
      rescue Exception
        ret = $!
      end
      q.push(ret)
    end

    resp = q.pop
    raise resp if resp
  end
  
  private
  def start_server
    raise "trouble starting server" unless EventMachine::reactor_thread?
    @dsock = EventMachine::open_datagram_socket(@ip, @options[:port],
                                                Server, self)
    @port = Socket.unpack_sockaddr_in(@dsock.get_sockname)[0]
  end
  
  def start_reactor
    return if EventMachine::reactor_running?

    EventMachine::error_handler do |e|
      puts "#{e.class}: #{e}"
      raise e
    end

    # Block until EM has successfully started up.
    q = Queue.new
    # This thread helps us avoid race conditions on the start and stop of
    # EventMachine's event loop.
    Thread.new do
      EventMachine.run do
        q.push(true)
      end
    end
    # Block waiting for EM's event loop to start up.
    q.pop
  end
  
  # Shutdown a Crocus instance that is running asynchronously. This method blocks
  # until Bud has been shutdown. If +stop_em+ is true, the EventMachine event
  # loop is also shutdown; this will interfere with the execution of any other
  # Bud instances in the same process (as well as anything else that happens to
  # use EventMachine).
  public
  def stop_bg(stop_em=false)
    schedule_and_wait do
      @dsock.close_connection if EventMachine::reactor_running?
    end

    if stop_em
      EventMachine::stop_event_loop
      EventMachine::reactor_thread.join
    end
  end
end
