require "./spec_helper"

module ValidationFixture
  @[GraphQL::InputObject]
  class Point < GraphQL::BaseInputObject
    getter x : Int32
    getter y : Int32?

    @[GraphQL::Field(arguments: {y: {name: "why"}})]
    def initialize(@x : Int32, @y : Int32? = nil)
    end
  end

  @[GraphQL::Object]
  class Thing < GraphQL::BaseObject
    @[GraphQL::Field]
    def name : String
      "thing"
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def hello : String?
      "hi"
    end

    @[GraphQL::Field(arguments: {name: {name: "who"}})]
    def greet(name : String) : String?
      "hello #{name}"
    end

    @[GraphQL::Field]
    def thing : Thing?
      Thing.new
    end

    @[GraphQL::Field]
    def things : Array(Thing)?
      [Thing.new]
    end

    @[GraphQL::Field]
    def point(p : Point) : String?
      "#{p.x},#{p.y.inspect}"
    end
  end
end

describe "validation" do
  schema = GraphQL::Schema.new(ValidationFixture::Query.new)

  it "resolves arguments by their schema name" do
    schema.execute(%({ greet(who: "you") })).should eq ({"data" => {"greet" => "hello you"}}).to_json
    schema.execute(%({ point(p: {x: 1, why: 2}) })).should eq ({"data" => {"point" => "1,2"}}).to_json
  end

  it "renders the overridden names in the schema" do
    sdl = schema.document.to_s
    sdl.should contain "greet(who: String!): String"
    sdl.should contain "why: Int"
  end

  it "reports unknown arguments" do
    schema.execute(%({ hello greet(who: "you", name: "x") })).should eq (
      {
        "data"   => {"hello" => "hi", "greet" => nil},
        "errors" => [{"message" => "unknown argument name on field greet", "path" => ["greet"]}],
      }
    ).to_json
    schema.execute(%({ hello(x: 1) })).should eq (
      {
        "data"   => {"hello" => nil},
        "errors" => [{"message" => "unknown argument x on field hello", "path" => ["hello"]}],
      }
    ).to_json
  end

  it "reports unknown input object fields" do
    schema.execute(%({ point(p: {x: 1, z: 2}) })).should eq (
      {
        "data"   => {"point" => nil},
        "errors" => [{"message" => "unknown field z on input object Point", "path" => ["point"]}],
      }
    ).to_json
  end

  it "reports unknown directives" do
    schema.execute(%({ hello @nope thing @skip(if: false) { name } })).should eq (
      {
        "data"   => {"thing" => {"name" => "thing"}},
        "errors" => [{"message" => "unknown directive @nope", "path" => ["hello"]}],
      }
    ).to_json
  end

  it "reports a selection set on a leaf field" do
    schema.execute(%({ hello { x } })).should eq (
      {
        "data"   => {"hello" => nil},
        "errors" => [{"message" => "field hello must not have a selection since its type has no subfields", "path" => ["hello"]}],
      }
    ).to_json
    schema.execute(%({ thing { __typename { x } } })).should eq (
      {
        "data"   => {"thing" => nil},
        "errors" => [{"message" => "field __typename must not have a selection since its type has no subfields", "path" => ["thing", "__typename"]}],
      }
    ).to_json
  end

  it "reports a missing selection set on an object field" do
    schema.execute(%({ thing things })).should eq (
      {
        "data"   => {"thing" => nil, "things" => nil},
        "errors" => [
          {"message" => "field thing must have a selection of subfields", "path" => ["thing"]},
          {"message" => "field things must have a selection of subfields", "path" => ["things"]},
        ],
      }
    ).to_json
  end

  it "reports a query without operations" do
    schema.execute("").should eq (
      {"errors" => [{"message" => "query does not contain an operation", "path" => [] of String}]}
    ).to_json
    schema.execute("fragment F on Query { hello }").should eq (
      {"errors" => [{"message" => "query does not contain an operation", "path" => [] of String}]}
    ).to_json
  end
end
