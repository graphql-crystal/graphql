require "./spec_helper"

module SerializationFixture
  @[GraphQL::Enum]
  enum Color
    Red
    Blue
  end

  @[GraphQL::Object]
  class Thing < GraphQL::BaseObject
    @[GraphQL::Field]
    def name : String
      "thing"
    end

    @[GraphQL::Field]
    def required : String
      raise "required failed"
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def a : String
      "a"
    end

    @[GraphQL::Field]
    def thing : Thing?
      Thing.new
    end

    @[GraphQL::Field]
    def b : Int32
      2
    end

    @[GraphQL::Field]
    def colors : Array(Color?)
      [Color::Red, nil, Color::Blue] of Color?
    end

    @[GraphQL::Field]
    def nan : Float64?
      Float64::NAN
    end

    @[GraphQL::Field]
    def infinities : Array(Float64)?
      [1.0, Float64::INFINITY]
    end

    @[GraphQL::Field]
    def required_nan : Float64
      Float64::NAN
    end

    @[GraphQL::Field]
    def boom : Int32?
      raise "boom"
    end

    @[GraphQL::Field]
    def id : GraphQL::Scalars::ID
      GraphQL::Scalars::ID.new("x1")
    end

    @[GraphQL::Field]
    def ids : Array(GraphQL::Scalars::ID?)
      [GraphQL::Scalars::ID.new("x1"), nil] of GraphQL::Scalars::ID?
    end

    @[GraphQL::Field]
    def big : GraphQL::Scalars::BigInt
      GraphQL::Scalars::BigInt.new(BigInt.new("123456789012345678901234567890"))
    end

    @[GraphQL::Field]
    def wrapped_nan : GraphQL::Scalars::Float?
      GraphQL::Scalars::Float.new(Float64::NAN)
    end
  end
end

# The sequential path writes leaf values straight into the parent while
# object values go through a buffer; both must produce the same documents
# as concurrent execution.
describe "serialization" do
  schema = GraphQL::Schema.new(SerializationFixture::Query.new)
  concurrent = -> { ctx = GraphQL::Context.new; ctx.max_concurrency = 8; ctx }

  it "keeps query order across leaf and object fields" do
    expected = ({"data" => {"a" => "a", "thing" => {"name" => "thing"}, "b" => 2, "colors" => ["Red", nil, "Blue"]}}).to_json
    schema.execute(%({ a thing { name } b colors })).should eq expected
    schema.execute(%({ a thing { name } b colors }), context: concurrent.call).should eq expected
  end

  it "writes built-in scalars like other leaves" do
    expected = (
      {
        "data"   => {"id" => "x1", "ids" => ["x1", nil], "big" => "123456789012345678901234567890", "wrappedNan" => nil},
        "errors" => [{"message" => "Float cannot represent non-finite value", "locations" => [{"line" => 1, "column" => 14}], "path" => ["wrappedNan"]}],
      }
    ).to_json
    schema.execute(%({ id ids big wrappedNan })).should eq expected
    schema.execute(%({ id ids big wrappedNan }), context: concurrent.call).should eq expected
  end

  it "reports a failed leaf next to the leaves around it" do
    expected = (
      {
        "data"   => {"a" => "a", "boom" => nil, "b" => 2},
        "errors" => [{"message" => "boom", "locations" => [{"line" => 1, "column" => 5}], "path" => ["boom"]}],
      }
    ).to_json
    schema.execute(%({ a boom b })).should eq expected
    schema.execute(%({ a boom b }), context: concurrent.call).should eq expected
  end

  it "rejects non-finite floats as errors instead of emitting invalid JSON" do
    expected = (
      {
        "data"   => {"a" => "a", "nan" => nil, "infinities" => nil},
        "errors" => [
          {"message" => "Float cannot represent non-finite value", "locations" => [{"line" => 1, "column" => 5}], "path" => ["nan"]},
          {"message" => "Float cannot represent non-finite value", "locations" => [{"line" => 1, "column" => 9}], "path" => ["infinities", 1]},
        ],
      }
    ).to_json
    schema.execute(%({ a nan infinities })).should eq expected
    schema.execute(%({ a nan infinities }), context: concurrent.call).should eq expected
  end

  it "propagates a non-finite float in a non-null field" do
    expected = (
      {
        "data"   => nil,
        "errors" => [{"message" => "Float cannot represent non-finite value", "locations" => [{"line" => 1, "column" => 3}], "path" => ["requiredNan"]}],
      }
    ).to_json
    schema.execute(%({ requiredNan })).should eq expected
    schema.execute(%({ requiredNan }), context: concurrent.call).should eq expected
  end

  it "still discards a buffered object whose non-null field fails" do
    expected = (
      {
        "data"   => {"a" => "a", "thing" => nil, "b" => 2},
        "errors" => [{"message" => "required failed", "locations" => [{"line" => 1, "column" => 18}], "path" => ["thing", "required"]}],
      }
    ).to_json
    schema.execute(%({ a thing { name required } b })).should eq expected
    schema.execute(%({ a thing { name required } b }), context: concurrent.call).should eq expected
  end
end
