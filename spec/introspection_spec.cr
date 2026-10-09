require "./spec_helper"

module IntrospectionFixture
  @[GraphQL::Scalar(specified_by_url: "https://example.com/upper")]
  record Upper, value : String do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      new(String.from_json(string_or_io).upcase)
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[GraphQL::Enum(values: {Red: {description: "Like a rose"}, Blue: {deprecated: "Use Navy"}})]
  enum Color
    Red
    Blue
    Navy
  end

  @[GraphQL::InputObject]
  class Filter < GraphQL::BaseInputObject
    getter text : String
    getter legacy : String?

    @[GraphQL::Field(arguments: {legacy: {deprecated: "Use text"}})]
    def initialize(@text : String, @legacy : String? = nil)
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field(arguments: {old: {deprecated: "Use filter"}})]
    def search(filter : Filter, old : String? = nil) : Upper
      Upper.new(filter.text)
    end

    @[GraphQL::Field]
    def color : Color
      Color::Red
    end
  end
end

# The query graphql-js generates with every option enabled, as sent by
# Apollo tooling and GraphiQL when input value deprecation is on.
FULL_INTROSPECTION = <<-GQL
  query IntrospectionQuery {
    __schema {
      description
      queryType { name kind }
      mutationType { name }
      subscriptionType { name }
      types { ...FullType }
      directives { name description isRepeatable locations args(includeDeprecated: true) { ...InputValue } }
    }
  }
  fragment FullType on __Type {
    kind name description specifiedByURL isOneOf
    fields(includeDeprecated: true) { name description args(includeDeprecated: true) { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason }
    inputFields(includeDeprecated: true) { ...InputValue }
    interfaces { ...TypeRef }
    enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason }
    possibleTypes { ...TypeRef }
  }
  fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue isDeprecated deprecationReason }
  fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name } } } }
  GQL

describe "introspection" do
  schema = GraphQL::Schema.new(IntrospectionFixture::Query.new)

  it "answers the full introspection query without errors" do
    result = JSON.parse(schema.execute(FULL_INTROSPECTION))
    result["errors"]?.should be_nil
    result["data"]["__schema"]["description"].raw.should be_nil
    result["data"]["__schema"]["directives"].as_a.map(&.["name"].as_s).sort.should eq ["deprecated", "include", "skip", "specifiedBy"]
    result["data"]["__schema"]["directives"].as_a.all? { |d| d["isRepeatable"] == false }.should be_true
  end

  it "reports specifiedByURL and isOneOf" do
    schema.execute(%({
      upper: __type(name: "Upper") { specifiedByURL isOneOf }
      filter: __type(name: "Filter") { specifiedByURL isOneOf }
    })).should eq (
      {
        "data" => {
          "upper"  => {"specifiedByURL" => "https://example.com/upper", "isOneOf" => nil},
          "filter" => {"specifiedByURL" => nil, "isOneOf" => false},
        },
      }
    ).to_json
    schema.document.to_s.should contain %(scalar Upper @specifiedBy(url: "https://example.com/upper"))
  end

  it "hides deprecated arguments and input fields unless asked" do
    schema.execute(%({
      query: __type(name: "Query") { fields { name args { name } all: args(includeDeprecated: true) { name isDeprecated deprecationReason } } }
      filter: __type(name: "Filter") { inputFields { name } all: inputFields(includeDeprecated: true) { name isDeprecated deprecationReason } }
    })).should eq (
      {
        "data" => {
          "query" => {
            "fields" => [
              {"name" => "color", "args" => [] of String, "all" => [] of String},
              {
                "name" => "search",
                "args" => [{"name" => "filter"}],
                "all"  => [
                  {"name" => "filter", "isDeprecated" => false, "deprecationReason" => nil},
                  {"name" => "old", "isDeprecated" => true, "deprecationReason" => "Use filter"},
                ],
              },
            ],
          },
          "filter" => {
            "inputFields" => [{"name" => "text"}],
            "all"         => [
              {"name" => "text", "isDeprecated" => false, "deprecationReason" => nil},
              {"name" => "legacy", "isDeprecated" => true, "deprecationReason" => "Use text"},
            ],
          },
        },
      }
    ).to_json
  end

  it "describes and deprecates enum values" do
    schema.execute(%({
      color: __type(name: "Color") {
        enumValues { name }
        all: enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason }
      }
    })).should eq (
      {
        "data" => {
          "color" => {
            "enumValues" => [{"name" => "Navy"}, {"name" => "Red"}],
            "all"        => [
              {"name" => "Blue", "description" => nil, "isDeprecated" => true, "deprecationReason" => "Use Navy"},
              {"name" => "Navy", "description" => nil, "isDeprecated" => false, "deprecationReason" => nil},
              {"name" => "Red", "description" => "Like a rose", "isDeprecated" => false, "deprecationReason" => nil},
            ],
          },
        },
      }
    ).to_json
    schema.document.to_s.should contain %(enum Color {\n  Blue @deprecated(reason: "Use Navy")\n  Navy\n\n  "Like a rose"\n  Red\n})
  end
end
