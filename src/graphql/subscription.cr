module GraphQL
  # A running subscription, returned by `Schema#subscribe`. Every event the
  # resolver's channel produces arrives as one response document.
  #
  # ```
  # subscription = schema.subscribe(%(subscription { messageAdded { text } }))
  # subscription.each { |response| socket.send(response) }
  # ```
  #
  # The stream ends when the resolver's channel closes. `close` ends it from
  # the consumer side and closes the resolver's channel too, so the
  # application learns the subscriber is gone.
  class Subscription
    # The raw response channel, for use in `select`.
    getter responses : Channel(String)

    # :nodoc:
    def initialize(@responses : Channel(String), &@on_close : ->)
    end

    # :nodoc:
    # A subscription that failed to start: it delivers `errors` once and is
    # already closed.
    def self.failed(errors : Array(Error)) : Subscription
      channel = Channel(String).new(1)
      channel.send({"errors" => errors}.to_json)
      channel.close
      new(channel) { }
    end

    # Next response, or nil once the stream has ended.
    def receive? : String?
      @responses.receive?
    end

    # Next response. Raises `Channel::ClosedError` once the stream has ended.
    def receive : String
      @responses.receive
    end

    # Yields every response until the stream ends.
    def each(& : String ->) : Nil
      while response = receive?
        yield response
      end
    end

    def closed? : Bool
      @responses.closed?
    end

    # Unsubscribes: closes the resolver's channel and the response stream.
    def close : Nil
      @on_close.call
      @responses.close
    end
  end
end
