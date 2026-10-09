module SubscriptionFixture
  @[GraphQL::Object]
  class Message < GraphQL::BaseObject
    def initialize(@text : String)
    end

    @[GraphQL::Field]
    def text : String
      @text
    end

    @[GraphQL::Field]
    def boom : String
      raise "boom"
    end

    @[GraphQL::Field]
    def maybe_boom : String?
      raise "maybe boom"
    end
  end

  MESSAGES = GraphQL::Broadcast(Message).new

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def ok : String
      "ok"
    end
  end

  @[GraphQL::Object]
  class Mutation < GraphQL::BaseMutation
    @[GraphQL::Field]
    def post(text : String) : String
      MESSAGES.publish(Message.new(text))
      text
    end
  end

  @[GraphQL::Object]
  class Subscription < GraphQL::BaseSubscription
    @[GraphQL::Field(description: "Every message as it is posted")]
    def message_added : Channel(Message)
      MESSAGES.subscribe
    end

    @[GraphQL::Field]
    def countdown(from : Int32) : Channel(Int32)
      channel = Channel(Int32).new
      spawn do
        from.downto(1) { |i| channel.send(i) }
        channel.close
      end
      channel
    end

    @[GraphQL::Field]
    def maybe_message : Channel(Message?)
      channel = Channel(Message?).new(2)
      channel.send(nil)
      channel.send(Message.new("there"))
      channel.close
      channel
    end
  end
end
