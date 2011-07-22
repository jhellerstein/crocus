require 'socket'

class Crocus
  class Server < EM::Connection #:nodoc: all
    def initialize(crocus)
      @crocus = crocus
      @pac = MessagePack::Unpacker.new
      super
    end

    def receive_data(data)
      # puts "got some data: #{data.inspect}"
      # Feed the received data to the deserializer
      @pac.feed data

      # streaming deserialize
      @pac.each do |obj|
        message_received(obj)
      end
    end

    def message_received(obj)
      # puts "got msg #{obj.inspect}"
      unless (obj.class <= Array and obj.length == 2 and not
              @crocus.sources[obj[0]].nil? and obj[1].class <= Array)
        raise "Bad inbound message of class #{obj.class}: #{obj.inspect}"
      end
      @crocus.sources[obj[0]] << obj[1]
    end
  end
end
