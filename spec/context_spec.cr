require "./spec_helper"

module ContextApi
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def value(ctx : Context) : Int32
      ctx.value
    end
  end

  class Context < GraphQL::Context
    getter value : Int32

    def initialize(@value)
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
end
