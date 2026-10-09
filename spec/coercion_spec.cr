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

    @[GraphQL::Field]
    def float(f : Float64) : Float64
      f
    end

    @[GraphQL::Field]
    def big(b : GraphQL::Scalars::BigInt) : String
      b.value.to_s
    end

    @[GraphQL::Field]
    def strings(list : Array(String)) : String
      list.join(",")
    end

    @[GraphQL::Field]
    def maybe_strings(list : Array(String?)) : String
      list.map(&.inspect).join(",")
    end

    @[GraphQL::Field]
    def matrix(rows : Array(Array(Int32))) : Int32
      rows.sum(&.sum)
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

  it "rejects an integer literal outside the 32-bit range for Int" do
    schema.execute(%({ int(n: 99999999999) })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "Int cannot represent non 32-bit signed integer value: 99999999999", "path" => ["int"]}],
      }
    ).to_json
  end

  it "widens a large integer literal to Float" do
    schema.execute(%({ float(f: 99999999999) })).should eq ({"data" => {"float" => 99999999999.0}}).to_json
  end

  it "passes large integer literals to BigInt" do
    schema.execute(%({ big(b: 123456789012345678901234567890) })).should eq (
      {"data" => {"big" => "123456789012345678901234567890"}}
    ).to_json
  end

  it "passes large integer variables to BigInt" do
    schema.execute(%(query ($b: BigInt!) { big(b: $b) }), {"b" => JSON::Any.new(99_999_999_999_i64)}).should eq (
      {"data" => {"big" => "99999999999"}}
    ).to_json
  end

  it "still accepts strings for BigInt" do
    schema.execute(%({ big(b: "123456789012345678901234567890") })).should eq (
      {"data" => {"big" => "123456789012345678901234567890"}}
    ).to_json
  end

  it "coerces a single value to a one-element list" do
    schema.execute(%({ strings(list: "one") })).should eq ({"data" => {"strings" => "one"}}).to_json
    schema.execute(%({ matrix(rows: 5) })).should eq ({"data" => {"matrix" => 5}}).to_json
  end

  it "names the argument when a list element has the wrong type" do
    schema.execute(%({ strings(list: ["a", 1]) })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "bad type for argument list", "path" => ["strings"]}],
      }
    ).to_json
  end

  it "rejects null elements in a list of non-null values" do
    schema.execute(%({ strings(list: ["a", null]) })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "bad type for argument list", "path" => ["strings"]}],
      }
    ).to_json
  end

  it "accepts null elements in a list of nullable values" do
    schema.execute(%({ maybeStrings(list: ["a", null]) })).should eq (
      {"data" => {"maybeStrings" => %("a",nil)}}
    ).to_json
    schema.execute(%(query ($l: [String]!) { maybeStrings(list: $l) }), {"l" => JSON.parse(%(["a", null]))}).should eq (
      {"data" => {"maybeStrings" => %("a",nil)}}
    ).to_json
  end
end
