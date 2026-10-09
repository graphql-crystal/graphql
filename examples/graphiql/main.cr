# GraphiQL in the browser against a schema with a query, a mutation and a
# subscription. Run with `shards install && crystal run main.cr`, then open
# http://localhost:3000. Try, in two tabs:
#
#   subscription { messageAdded { id text } }
#   mutation { post(text: "hello") { id } }
#
require "kemal"
require "graphql"
require "graphql/transport/ws"

@[GraphQL::Object]
class Message < GraphQL::BaseObject
  @@next_id = 0

  @[GraphQL::Field]
  getter id : Int32

  @[GraphQL::Field]
  getter text : String

  def initialize(@text)
    @id = (@@next_id += 1)
  end
end

MESSAGES = [] of Message
POSTED   = GraphQL::Broadcast(Message).new

@[GraphQL::Object]
class Query < GraphQL::BaseQuery
  @[GraphQL::Field]
  def hello(name : String = "world") : String
    "Hello, #{name}!"
  end

  @[GraphQL::Field(description: "Every message posted so far")]
  def messages : Array(Message)
    MESSAGES
  end
end

@[GraphQL::Object]
class Mutation < GraphQL::BaseMutation
  @[GraphQL::Field]
  def post(text : String) : Message
    message = Message.new(text)
    MESSAGES << message
    POSTED.publish(message)
    message
  end
end

@[GraphQL::Object]
class Subscription < GraphQL::BaseSubscription
  @[GraphQL::Field(description: "Each message as it is posted")]
  def message_added : Channel(Message)
    POSTED.subscribe
  end
end

schema = GraphQL::Schema.new(Query.new, Mutation.new, Subscription.new)

# Queries and mutations over HTTP.
post "/graphql" do |env|
  env.response.content_type = "application/json"

  query = env.params.json["query"].as(String)
  variables = env.params.json["variables"]?.as(Hash(String, JSON::Any)?)
  operation_name = env.params.json["operationName"]?.as(String?)

  schema.execute(query, variables, operation_name)
end

# Subscriptions over a WebSocket on the same path. Browsers insist that the
# server echoes the `graphql-transport-ws` subprotocol, which Kemal's own
# `ws` helper cannot do, so the standard library handler is mounted instead.
# Requests that are not upgrades fall through to the route above.
subscriptions = HTTP::WebSocketHandler.new([GraphQL::Transport::WebSocket::PROTOCOL]) do |socket, _http|
  GraphQL::Transport::WebSocket.new(schema, socket)
end
use "/graphql", subscriptions

get "/" do
  render "index.html"
end

Kemal.run
