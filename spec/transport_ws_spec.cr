require "./spec_helper"
require "../src/graphql/transport/ws"

# Collects messages from a client socket and waits for them.
private class Client
  getter messages = [] of JSON::Any
  getter close_code : Int32? = nil
  @socket : HTTP::WebSocket

  def initialize(port : Int32)
    @socket = HTTP::WebSocket.new("ws://127.0.0.1:#{port}/graphql")
    @socket.on_message { |m| @messages << JSON.parse(m) }
    @socket.on_close { |code, _| @close_code = code.to_i }
    spawn { @socket.run }
  end

  def send(message)
    @socket.send(message.to_json)
  end

  # Polls up to two seconds, in 5 ms steps.
  def self.wait_until(&) : Nil
    400.times do
      return if yield
      sleep 5.milliseconds
    end
  end

  def await(count : Int32) : Array(JSON::Any)
    Client.wait_until { @messages.size >= count }
    @messages.size.should be >= count
    @messages
  end

  def await_close : Int32
    Client.wait_until { !@close_code.nil? }
    @close_code.not_nil!
  end

  def close
    @socket.close
  end
end

describe GraphQL::Transport::WebSocket do
  schema = GraphQL::Schema.new(SubscriptionFixture::Query.new, SubscriptionFixture::Mutation.new, SubscriptionFixture::Subscription.new)
  # Subprotocol negotiation (`HTTP::WebSocketHandler.new([PROTOCOL])`) needs
  # Crystal 1.20; the handler is created without it so the suite runs on the
  # oldest supported compiler. The client here does not request one.
  server = HTTP::Server.new([
    HTTP::WebSocketHandler.new do |socket, _http|
      GraphQL::Transport::WebSocket.new(schema, socket)
    end,
  ])
  port = server.bind_unused_port("127.0.0.1").port
  spawn { server.listen }

  it "acknowledges the connection and answers pings" do
    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({type: "ping"})
    messages = client.await(2)
    messages[0]["type"].should eq "connection_ack"
    messages[1]["type"].should eq "pong"
    client.close
  end

  it "streams a subscription and completes when the source closes" do
    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({id: "1", type: "subscribe", payload: {query: "subscription { countdown(from: 2) }"}})
    messages = client.await(4)
    messages[1].should eq JSON.parse(%({"id":"1","type":"next","payload":{"data":{"countdown":2}}}))
    messages[2].should eq JSON.parse(%({"id":"1","type":"next","payload":{"data":{"countdown":1}}}))
    messages[3].should eq JSON.parse(%({"id":"1","type":"complete"}))
    client.close
  end

  it "executes queries and mutations once" do
    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({id: "q", type: "subscribe", payload: {query: "{ ok }"}})
    messages = client.await(3)
    messages[1].should eq JSON.parse(%({"id":"q","type":"next","payload":{"data":{"ok":"ok"}}}))
    messages[2].should eq JSON.parse(%({"id":"q","type":"complete"}))
    client.close
  end

  it "stops a subscription when the client completes it" do
    before = SubscriptionFixture::MESSAGES.size

    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({id: "s", type: "subscribe", payload: {query: "subscription { messageAdded { text } }"}})
    client.await(1)
    Client.wait_until { SubscriptionFixture::MESSAGES.size == before + 1 }
    SubscriptionFixture::MESSAGES.size.should eq before + 1

    client.send({id: "s", type: "complete"})
    Client.wait_until { SubscriptionFixture::MESSAGES.size == before }
    SubscriptionFixture::MESSAGES.size.should eq before

    schema.execute(%(mutation { post(text: "after") }))
    sleep 20.milliseconds
    client.messages.map(&.["type"]).should eq ["connection_ack"]
    client.close
  end

  it "reports a subscription that cannot start as an error message" do
    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({id: "e", type: "subscribe", payload: {query: "subscription { countdown }"}})
    messages = client.await(2)
    messages[1]["type"].should eq "error"
    messages[1]["payload"][0]["message"].should eq "missing required argument from"
    client.close
  end

  it "closes the socket when subscribing before connection_init" do
    client = Client.new(port)
    client.send({id: "1", type: "subscribe", payload: {query: "{ ok }"}})
    client.await_close.should eq 4401
  end

  it "closes the socket on a duplicate subscription id" do
    client = Client.new(port)
    client.send({type: "connection_init"})
    client.send({id: "d", type: "subscribe", payload: {query: "subscription { messageAdded { text } }"}})
    client.send({id: "d", type: "subscribe", payload: {query: "subscription { messageAdded { text } }"}})
    client.await_close.should eq 4409
  end
end
