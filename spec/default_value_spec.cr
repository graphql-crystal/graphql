require "./spec_helper"

module DefaultValueApi
  @[GraphQL::Enum]
  enum Color
    RED
    GREEN
  end

  @[GraphQL::InputObject]
  class GoalInput < GraphQL::BaseInputObject
    getter title : String
    getter milestones : Array(String)
    getter colors : Array(Color)

    @[GraphQL::Field]
    def initialize(@title : String, @milestones : Array(String) = [] of String, @colors : Array(Color) = [Color::RED])
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def goal(input : GoalInput) : String
      "#{input.title}: #{input.milestones.join(",")} #{input.colors.join(",")}"
    end

    @[GraphQL::Field]
    def tags(tags : Array(String) = ["a", "b"]) : String
      tags.join(",")
    end
  end
end

describe "default values" do
  schema = GraphQL::Schema.new(DefaultValueApi::Query.new)

  it "renders array defaults in the schema" do
    document = schema.document.to_s
    document.should contain "milestones: [String!]! = []"
    document.should contain "colors: [Color!]! = [RED]"
    document.should contain %(tags(tags: [String!]! = ["a", "b"]): String!)
  end

  it "applies array defaults when the value is omitted" do
    schema.execute(%({ goal(input: {title: "t"}) tags })).should eq(
      {"data" => {"goal" => "t:  RED", "tags" => "a,b"}}.to_json
    )
  end

  it "uses provided values over array defaults" do
    schema.execute(%({ goal(input: {title: "t", milestones: ["m"], colors: [GREEN]}) tags(tags: ["x"]) })).should eq(
      {"data" => {"goal" => "t: m GREEN", "tags" => "x"}}.to_json
    )
  end
end
