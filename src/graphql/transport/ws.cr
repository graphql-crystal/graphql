require "http/web_socket"
require "../../graphql"

module GraphQL::Transport
  # Serves a schema over a WebSocket with the `graphql-transport-ws`
  # protocol used by graphql-ws, Apollo Client, urql and Relay. Not
  # required by `require "graphql"`; load it with
  # `require "graphql/transport/ws"`.
  #
  # Hand each accepted socket to a new instance. The block builds the
  # `GraphQL::Context` for every operation on the connection:
  #
  # ```
  # handler = HTTP::WebSocketHandler.new([GraphQL::Transport::WebSocket::PROTOCOL]) do |socket, http|
  #   GraphQL::Transport::WebSocket.new(schema, socket) { MyContext.new(http.request) }
  # end
  # ```
  #
  # Subscriptions stream until the client sends `complete` or disconnects.
  # Queries and mutations sent over the socket are executed once and
  # answered with `next` and `complete`.
  class WebSocket
    PROTOCOL = "graphql-transport-ws"

    @acked = false

    def initialize(@schema : GraphQL::Schema, @socket : HTTP::WebSocket, &@context : -> GraphQL::Context)
      @subscriptions = Hash(String, GraphQL::Subscription).new
      @write = Mutex.new

      @socket.on_message { |message| handle(message) }
      @socket.on_close { |_code, _reason| close_all }
    end

    def self.new(schema : GraphQL::Schema, socket : HTTP::WebSocket)
      new(schema, socket) { GraphQL::Context.new }
    end

    private def handle(raw : String) : Nil
      message = begin
        JSON.parse(raw)
      rescue JSON::ParseException
        return fail(4400, "Invalid message")
      end

      type = message["type"]?.try(&.as_s?)

      case type
      when "connection_init"
        return fail(4429, "Too many initialisation requests") if @acked
        @acked = true
        send(%({"type":"connection_ack"}))
      when "ping"
        send(%({"type":"pong"}))
      when "pong"
        # keep-alive reply, nothing to do
      when "subscribe"
        return fail(4401, "Unauthorized") unless @acked
        id = message["id"]?.try(&.as_s?) || return fail(4400, "Missing id")
        return fail(4409, "Subscriber for #{id} already exists") if @subscriptions.has_key?(id)
        payload = message["payload"]? || return fail(4400, "Missing payload")
        query = payload["query"]?.try(&.as_s?) || return fail(4400, "Missing query")
        variables = payload["variables"]?.try(&.as_h?)
        operation_name = payload["operationName"]?.try(&.as_s?)
        start(id, query, variables, operation_name)
      when "complete"
        if id = message["id"]?.try(&.as_s?)
          @subscriptions.delete(id).try &.close
        end
      else
        fail(4400, "Unknown message type #{type.inspect}")
      end
    end

    private def start(id : String, query : String, variables : Hash(String, JSON::Any)?, operation_name : String?) : Nil
      context = @context.call

      if subscription?(query, operation_name)
        subscription = @schema.subscribe(query, variables, operation_name, context)
        @subscriptions[id] = subscription

        spawn do
          while response = subscription.receive?
            if response.starts_with?(%({"errors"))
              # the subscription could not be started
              send(%({"id":#{id.to_json},"type":"error","payload":#{JSON.parse(response)["errors"].to_json}}))
            else
              send(%({"id":#{id.to_json},"type":"next","payload":#{response}}))
            end
          end

          # a complete from the client already removed the entry
          send(%({"id":#{id.to_json},"type":"complete"})) if @subscriptions.delete(id)
        end
      else
        result = @schema.execute(query, variables, operation_name, context)
        send(%({"id":#{id.to_json},"type":"next","payload":#{result}}))
        send(%({"id":#{id.to_json},"type":"complete"}))
      end
    end

    # Whether the operation the request selects is a subscription. Requests
    # that do not parse are handed to `execute`, which reports the error.
    private def subscription?(query : String, operation_name : String?) : Bool
      operations = GraphQL::Language.parse(query).definitions.select(GraphQL::Language::OperationDefinition)
      operation = operation_name ? operations.find { |o| o.name == operation_name } : (operations.size == 1 ? operations.first : nil)
      operation.try(&.operation_type) == "subscription"
    rescue GraphQL::ParserError
      false
    end

    private def send(message : String) : Nil
      @write.synchronize { @socket.send(message) }
    rescue IO::Error
      # the socket is gone; on_close cleans up
    end

    private def fail(code : Int32, reason : String) : Nil
      close_all
      @socket.close(code, reason)
    rescue IO::Error
    end

    private def close_all : Nil
      @subscriptions.each_value &.close
      @subscriptions.clear
    end
  end
end
