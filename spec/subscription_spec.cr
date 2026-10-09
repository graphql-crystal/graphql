require "./spec_helper"

private def drain(subscription : GraphQL::Subscription) : Array(String)
  responses = [] of String
  subscription.each { |response| responses << response }
  responses
end

describe "subscriptions" do
  schema = GraphQL::Schema.new(SubscriptionFixture::Query.new, SubscriptionFixture::Mutation.new, SubscriptionFixture::Subscription.new)

  it "renders the subscription type with the channel's element type" do
    sdl = schema.document.to_s
    sdl.should contain %(type Subscription {\n  countdown(from: Int!): Int!\n  maybeMessage: Message\n\n  "Every message as it is posted"\n  messageAdded: Message!\n})
    schema.execute(%({ __schema { subscriptionType { name } } })).should eq (
      {"data" => {"__schema" => {"subscriptionType" => {"name" => "Subscription"}}}}
    ).to_json
  end

  it "delivers one response per event and closes with the source" do
    drain(schema.subscribe(%(subscription { countdown(from: 3) }))).should eq [
      %({"data":{"countdown":3}}),
      %({"data":{"countdown":2}}),
      %({"data":{"countdown":1}}),
    ]
  end

  it "honors aliases and variables" do
    drain(schema.subscribe(%(subscription ($n: Int!) { n: countdown(from: $n) }), {"n" => JSON::Any.new(1_i64)})).should eq [
      %({"data":{"n":1}}),
    ]
  end

  it "renders nullable events as null" do
    drain(schema.subscribe(%(subscription { maybeMessage { text } }))).should eq [
      %({"data":{"maybeMessage":null}}),
      %({"data":{"maybeMessage":{"text":"there"}}}),
    ]
  end

  it "streams values published from a mutation" do
    before = SubscriptionFixture::MESSAGES.size

    subscription = schema.subscribe(%(subscription { messageAdded { text } }))
    SubscriptionFixture::MESSAGES.size.should eq before + 1
    schema.execute(%(mutation { post(text: "hi") }))
    schema.execute(%(mutation { post(text: "there") }))
    subscription.receive.should eq %({"data":{"messageAdded":{"text":"hi"}}})
    subscription.receive.should eq %({"data":{"messageAdded":{"text":"there"}}})

    subscription.close
    subscription.closed?.should be_true
    schema.execute(%(mutation { post(text: "nobody listens") }))
    SubscriptionFixture::MESSAGES.size.should eq before
  end

  it "reports field errors per event and nulls nullable fields" do
    subscription = schema.subscribe(%(subscription {\n  messageAdded { text maybeBoom }\n}))
    schema.execute(%(mutation { post(text: "hi") }))
    subscription.receive.should eq (
      {
        "data"   => {"messageAdded" => {"text" => "hi", "maybeBoom" => nil}},
        "errors" => [{"message" => "maybe boom", "locations" => [{"line" => 2, "column" => 23}], "path" => ["messageAdded", "maybeBoom"]}],
      }
    ).to_json
    subscription.close
  end

  it "propagates a non-null failure to data" do
    subscription = schema.subscribe(%(subscription { messageAdded { boom } }))
    schema.execute(%(mutation { post(text: "hi") }))
    subscription.receive.should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "boom", "locations" => [{"line" => 1, "column" => 31}], "path" => ["messageAdded", "boom"]}],
      }
    ).to_json
    subscription.close
  end

  it "rejects more than one root field" do
    drain(schema.subscribe(%(subscription { countdown(from: 1) messageAdded { text } }))).should eq [
      ({"errors" => [{"message" => "subscription operations must select exactly one root field"}]}).to_json,
    ]
  end

  it "reports resolver validation errors at the field" do
    drain(schema.subscribe(%(subscription { countdown }))).should eq [
      ({"errors" => [{"message" => "missing required argument from", "locations" => [{"line" => 1, "column" => 16}], "path" => ["countdown"]}]}).to_json,
    ]
    drain(schema.subscribe(%(subscription { nope }))).should eq [
      ({"errors" => [{"message" => "Field is not defined: nope", "locations" => [{"line" => 1, "column" => 16}], "path" => ["nope"]}]}).to_json,
    ]
  end

  it "reports request errors" do
    drain(schema.subscribe(%[subscription { countdown(from: 1 }])).should eq [ # ameba:disable Style/PercentLiteralDelimiters
      ({"errors" => [{"message" => "Expected Name, found BRACE_R "}]}).to_json,
    ]
    drain(schema.subscribe(%({ ok }))).should eq [
      ({"errors" => [{"message" => "query operations must be run with Schema#execute"}]}).to_json,
    ]
    schema.execute(%(subscription { countdown(from: 1) })).should eq (
      {"errors" => [{"message" => "subscription operations must be started with Schema#subscribe"}]}
    ).to_json
  end

  it "refuses subscriptions when the schema has no subscription type" do
    drain(GraphQL::Schema.new(SubscriptionFixture::Query.new).subscribe(%(subscription { countdown(from: 1) }))).should eq [
      ({"errors" => [{"message" => "subscription operations are not supported"}]}).to_json,
    ]
  end
end

describe GraphQL::Broadcast do
  it "delivers to every subscriber and drops closed ones" do
    broadcast = GraphQL::Broadcast(Int32).new
    a = broadcast.subscribe
    b = broadcast.subscribe
    broadcast.publish(1)
    a.receive.should eq 1
    b.receive.should eq 1

    a.close
    broadcast.size.should eq 1
    broadcast.publish(2)
    b.receive.should eq 2

    broadcast.unsubscribe(b)
    broadcast.size.should eq 0
    b.closed?.should be_true
  end

  it "skips a subscriber whose buffer is full instead of blocking" do
    broadcast = GraphQL::Broadcast(Int32).new(buffer: 1)
    slow = broadcast.subscribe
    broadcast.publish(1)
    broadcast.publish(2)
    slow.receive.should eq 1
    broadcast.publish(3)
    slow.receive.should eq 3
  end
end
