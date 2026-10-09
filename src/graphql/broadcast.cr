module GraphQL
  # Fans values out to any number of subscribers, each receiving them on its
  # own channel. Meant for subscription resolvers: a mutation publishes, and
  # a subscription field returns `subscribe`.
  #
  # ```
  # MESSAGES = GraphQL::Broadcast(Message).new
  #
  # @[GraphQL::Field]
  # def message_added : Channel(Message)
  #   MESSAGES.subscribe
  # end
  # ```
  #
  # Every subscriber channel buffers `buffer` values. A subscriber that has
  # not drained its buffer misses the next value rather than blocking the
  # publisher and every other subscriber. Closed channels are dropped on the
  # next publish.
  class Broadcast(T)
    def initialize(@buffer : Int32 = 16)
      @subscribers = [] of Channel(T)
      @mutex = Mutex.new
    end

    def subscribe : Channel(T)
      channel = Channel(T).new(@buffer)
      @mutex.synchronize { @subscribers << channel }
      channel
    end

    def unsubscribe(channel : Channel(T)) : Nil
      @mutex.synchronize { @subscribers.delete(channel) }
      channel.close
    end

    def publish(value : T) : Nil
      closed = [] of Channel(T)

      @mutex.synchronize { @subscribers.dup }.each do |channel|
        begin
          select
          when channel.send(value)
          else
            # full: the subscriber is not keeping up, skip this value for it
          end
        rescue Channel::ClosedError
          closed << channel
        end
      end

      @mutex.synchronize { closed.each { |c| @subscribers.delete(c) } } unless closed.empty?
    end

    # Number of open subscriber channels.
    def size : Int32
      @mutex.synchronize { @subscribers.count { |c| !c.closed? } }
    end

    def close : Nil
      @mutex.synchronize do
        @subscribers.each &.close
        @subscribers.clear
      end
    end
  end
end
