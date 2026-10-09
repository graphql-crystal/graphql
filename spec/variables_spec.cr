require "./spec_helper"

module VariablesFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def greet(name : String?) : String
      "hello #{name || "nobody"}"
    end

    @[GraphQL::Field]
    def double(n : Int32) : Int32
      n * 2
    end
  end
end

describe "variables" do
  schema = GraphQL::Schema.new(VariablesFixture::Query.new)

  it "applies the default value from the variable definition" do
    schema.execute(%(query ($name: String = "default") { greet(name: $name) })).should eq (
      {"data" => {"greet" => "hello default"}}
    ).to_json
  end

  it "prefers the provided value over the default" do
    schema.execute(
      %(query ($name: String = "default") { greet(name: $name) }),
      {"name" => JSON::Any.new("sent")}
    ).should eq ({"data" => {"greet" => "hello sent"}}).to_json
  end

  it "treats an omitted nullable variable as null" do
    schema.execute(%(query ($name: String) { greet(name: $name) })).should eq (
      {"data" => {"greet" => "hello nobody"}}
    ).to_json
    schema.execute(%(query ($name: String) { greet(name: $name) }), {} of String => JSON::Any).should eq (
      {"data" => {"greet" => "hello nobody"}}
    ).to_json
  end

  it "accepts an explicit null variable" do
    schema.execute(
      %(query ($name: String) { greet(name: $name) }),
      {"name" => JSON::Any.new(nil)}
    ).should eq ({"data" => {"greet" => "hello nobody"}}).to_json
  end

  it "accepts a null literal for a nullable argument" do
    schema.execute(%({ greet(name: null) })).should eq (
      {"data" => {"greet" => "hello nobody"}}
    ).to_json
  end

  it "rejects an omitted non-null variable" do
    schema.execute(%(query ($n: Int!) { double(n: $n) })).should eq (
      {"errors" => [{"message" => "missing required variable n"}]}
    ).to_json
  end

  it "rejects a null literal for a non-null argument" do
    schema.execute(%({ double(n: null) })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "missing required argument n", "locations" => [{"line" => 1, "column" => 3}], "path" => ["double"]}],
      }
    ).to_json
  end

  it "rejects an integer variable outside the 32-bit range" do
    schema.execute(
      %(query ($n: Int!) { double(n: $n) }),
      {"n" => JSON::Any.new(99_999_999_999_i64)}
    ).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "Int cannot represent non 32-bit signed integer value: 99999999999", "locations" => [{"line" => 1, "column" => 20}], "path" => ["double"]}],
      }
    ).to_json
  end

  it "still resolves variables the operation does not declare" do
    schema.execute(%({ double(n: $n) }), {"n" => JSON::Any.new(21_i64)}).should eq (
      {"data" => {"double" => 42}}
    ).to_json
  end
end
