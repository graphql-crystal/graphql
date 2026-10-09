require "./spec_helper"

module DepthFixture
  @[GraphQL::Object]
  class Node < GraphQL::BaseObject
    @[GraphQL::Field]
    def child : Node
      Node.new
    end

    @[GraphQL::Field]
    def sum(values : Array(Array(Int32))) : Int32
      values.sum(&.sum)
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def node : Node
      Node.new
    end
  end
end

private def nested_selection(depth : Int32) : String
  "{ " + "node { " + "child { " * (depth - 2) + "__typename" + " }" * (depth - 1) + " }"
end

describe "nesting depth" do
  schema = GraphQL::Schema.new(DepthFixture::Query.new)

  it "resolves queries within the limit" do
    JSON.parse(schema.execute(nested_selection(100)))["errors"]?.should be_nil
  end

  it "rejects selection sets nested beyond the limit" do
    schema.execute(nested_selection(101)).should eq (
      {"errors" => [{"message" => "query nesting depth exceeds 100"}]}
    ).to_json
  end

  it "survives hostile depths instead of overflowing the stack" do
    JSON.parse(schema.execute(nested_selection(20_000)))["errors"][0]["message"].should eq "query nesting depth exceeds 100"
    lists = "{ node { sum(values: " + "[" * 20_000 + "]" * 20_000 + ") } }"
    JSON.parse(schema.execute(lists))["errors"][0]["message"].should eq "query nesting depth exceeds 100"
    objects = "{ node(x: " + "{a: " * 20_000 + "1" + "}" * 20_000 + ") { __typename } }"
    JSON.parse(schema.execute(objects))["errors"][0]["message"].should eq "query nesting depth exceeds 100"
  end

  it "counts lists and input objects toward the depth" do
    schema.execute("{ node { sum(values: [[1, 2], [3]]) } }").should eq ({"data" => {"node" => {"sum" => 6}}}).to_json
    ctx = GraphQL::Context.new
    ctx.max_depth = 3
    schema.execute("{ node { sum(values: [[1]]) } }", context: ctx).should eq (
      {"errors" => [{"message" => "query nesting depth exceeds 3"}]}
    ).to_json
  end

  it "is configurable through the context" do
    ctx = GraphQL::Context.new
    ctx.max_depth = 5
    schema.execute(nested_selection(6), context: ctx).should eq (
      {"errors" => [{"message" => "query nesting depth exceeds 5"}]}
    ).to_json
    ctx = GraphQL::Context.new
    ctx.max_depth = 500
    JSON.parse(schema.execute(nested_selection(400), context: ctx))["errors"]?.should be_nil
  end
end
