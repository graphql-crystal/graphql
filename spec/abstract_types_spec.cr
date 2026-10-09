require "./spec_helper"

describe "interfaces and unions" do
  schema = GraphQL::Schema.new(AbstractTypes::Query.new)

  it "renders interfaces, implementations and unions in the schema" do
    sdl = schema.document.to_s
    sdl.should contain %("A character in the saga"\ninterface Character {\n  greeting: String!\n  name: String!\n})
    sdl.should contain "type Human implements Character {"
    sdl.should contain "type Droid implements Character {"
    sdl.should contain "union SearchResult = Human | Starship"
    sdl.should contain "hero: Character!"
    sdl.should contain "search: [SearchResult!]!"
  end

  it "resolves interface fields and the concrete type name" do
    schema.execute(%({ hero { __typename name greeting } })).should eq (
      {"data" => {"hero" => {"__typename" => "Human", "name" => "Luke", "greeting" => "I am Luke"}}}
    ).to_json
  end

  it "applies fragments by concrete type and by interface" do
    schema.execute(%(
      {
        characters {
          ... on Character { name }
          ... on Human { homePlanet }
          ...Droid
        }
      }
      fragment Droid on Droid { primaryFunction }
    )).should eq (
      {
        "data" => {
          "characters" => [
            {"name" => "Luke", "homePlanet" => "Tatooine"},
            {"name" => "R2-D2", "primaryFunction" => "astromech"},
          ],
        },
      }
    ).to_json
  end

  it "returns null for a missing interface value" do
    schema.execute(%({ missing { name } })).should eq ({"data" => {"missing" => nil}}).to_json
  end

  it "resolves union members through type conditions" do
    schema.execute(%(
      {
        search {
          __typename
          ... on Human { name }
          ... on Starship { length }
          ... on Character { greeting }
        }
      }
    )).should eq (
      {
        "data" => {
          "search" => [
            {"__typename" => "Human", "name" => "Leia", "greeting" => "I am Leia"},
            {"__typename" => "Starship", "length" => 34.37},
          ],
        },
      }
    ).to_json
  end

  it "exposes interfaces and possible types through introspection" do
    schema.execute(%(
      {
        human: __type(name: "Human") { kind interfaces { name } possibleTypes { name } }
        character: __type(name: "Character") { kind interfaces { name } possibleTypes { name } }
        search: __type(name: "SearchResult") { kind possibleTypes { name } }
      }
    )).should eq (
      {
        "data" => {
          "human"     => {"kind" => "OBJECT", "interfaces" => [{"name" => "Character"}], "possibleTypes" => nil},
          "character" => {"kind" => "INTERFACE", "interfaces" => [] of String, "possibleTypes" => [{"name" => "Droid"}, {"name" => "Human"}]},
          "search"    => {"kind" => "UNION", "possibleTypes" => [{"name" => "Human"}, {"name" => "Starship"}]},
        },
      }
    ).to_json
  end
end
