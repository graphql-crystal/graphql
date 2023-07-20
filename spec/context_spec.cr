require "./spec_helper"

module ContextApi
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def value(ctx : Context) : Int32
      ctx.value
    end

    @[GraphQL::Field]
    def exception(message : String) : Int32
      raise message
    end
  end

  class Context < GraphQL::Context
    getter value : Int32

    def initialize(@value)
    end
  end

  class ExceptionContext < GraphQL::Context
    def handle_exception(ex : ::Exception) : String?
      raise ex
    end
  end
end

describe GraphQL::Context do
  it "returns value from context" do
    value = 1337

    ctx = ContextApi::Context.new(value)
    schema = GraphQL::Schema.new(ContextApi::Query.new)

    query = %(
      {
        value
      }
    )

    schema.execute(query, context: ctx).should eq (
      {
        "data" => {
          "value" => value,
        },
      }
    ).to_json
  end

  it "handles exceptions" do
    ctx = ContextApi::Context.new(1337)
    schema = GraphQL::Schema.new(ContextApi::Query.new)

    query = %(
      {
        exception(message: "boom")
      }
    )

    schema.execute(query, context: ctx).should eq (
      {
        "data"   => {} of String => JSON::Any,
        "errors" => [
          {"message" => "boom", "path" => ["exception"]},
        ],
      }
    ).to_json
  end

  it "bubbles up exceptions" do
    ctx = ContextApi::ExceptionContext.new
    schema = GraphQL::Schema.new(ContextApi::Query.new)

    query = %(
      {
        exception(message: "error")
      }
    )

    expect_raises(Exception, "error") do
      schema.execute(query, context: ctx)
    end
  end
end
