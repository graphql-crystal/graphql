require "./spec_helper"

module CoercionFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def id(id : GraphQL::Scalars::ID) : String
      id.value
    end

    @[GraphQL::Field]
    def int(n : Int32) : Int32
      n
    end
  end
end

describe "input coercion" do
  schema = GraphQL::Schema.new(CoercionFixture::Query.new)

  it "accepts an integer literal for ID" do
    schema.execute(%({ id(id: 4) })).should eq ({"data" => {"id" => "4"}}).to_json
  end

  it "accepts an integer variable for ID" do
    schema.execute(%(query ($id: ID!) { id(id: $id) }), {"id" => JSON::Any.new(4_i64)}).should eq (
      {"data" => {"id" => "4"}}
    ).to_json
  end

  it "accepts a string for ID" do
    schema.execute(%({ id(id: "abc") })).should eq ({"data" => {"id" => "abc"}}).to_json
  end

  it "rejects an integer literal outside the 32-bit range" do
    schema.execute(%({ int(n: 99999999999) })).should eq (
      {"errors" => [{"message" => "Int cannot represent non 32-bit signed integer value: 99999999999", "path" => [] of String}]}
    ).to_json
  end
end
