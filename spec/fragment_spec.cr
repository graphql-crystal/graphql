require "./spec_helper"

describe "fragments" do
  schema = GraphQL::Schema.new(StarWars::Query.new)

  it "keeps fields in query order across fragment spreads" do
    schema.execute(%(
      {
        luke: human(id: "1000") { name }
        ...Leia
        han: human(id: "1002") { name }
      }
      fragment Leia on Query {
        leia: human(id: "1003") { name }
      }
    )).should eq (
      {
        "data" => {
          "luke" => {"name" => "Luke Skywalker"},
          "leia" => {"name" => "Leia Organa"},
          "han"  => {"name" => "Han Solo"},
        },
      }
    ).to_json
  end

  it "keeps fields in query order across inline fragments" do
    schema.execute(%(
      {
        luke: human(id: "1000") { name }
        ... { leia: human(id: "1003") { name } }
        han: human(id: "1002") { name }
      }
    )).should eq (
      {
        "data" => {
          "luke" => {"name" => "Luke Skywalker"},
          "leia" => {"name" => "Leia Organa"},
          "han"  => {"name" => "Han Solo"},
        },
      }
    ).to_json
  end

  it "merges fields with the same response key" do
    schema.execute(%(
      {
        ...Name
        human(id: "1000") { homePlanet }
      }
      fragment Name on Query {
        human(id: "1000") { name }
      }
    )).should eq (
      {
        "data" => {
          "human" => {"name" => "Luke Skywalker", "homePlanet" => "Tatooine"},
        },
      }
    ).to_json
  end

  it "skips fragment spreads with directives" do
    schema.execute(%(
      query ($skip: Boolean!) {
        luke: human(id: "1000") { name }
        ...Leia @skip(if: $skip)
      }
      fragment Leia on Query {
        leia: human(id: "1003") { name }
      }
    ), {"skip" => JSON::Any.new(true)}).should eq (
      {"data" => {"luke" => {"name" => "Luke Skywalker"}}}
    ).to_json
  end

  it "reports a fragment that spreads itself instead of recursing forever" do
    schema.execute(%(
      { ...Loop }
      fragment Loop on Query {
        luke: human(id: "1000") { name }
        ...Loop
      }
    )).should eq (
      {
        "data"   => {"luke" => {"name" => "Luke Skywalker"}},
        "errors" => [{"message" => "fragment Loop spreads itself", "locations" => [{"line" => 5, "column" => 9}], "path" => ["Loop"]}],
      }
    ).to_json
  end

  it "reports a cycle through several fragments" do
    schema.execute(%(
      { ...A }
      fragment A on Query { ...B }
      fragment B on Query { ...A }
    )).should eq (
      {
        "data"   => {} of String => String,
        "errors" => [{"message" => "fragment A spreads itself", "locations" => [{"line" => 4, "column" => 29}], "path" => ["A"]}],
      }
    ).to_json
  end

  it "allows the same fragment in sibling positions" do
    schema.execute(%(
      {
        luke: human(id: "1000") { ...Name }
        leia: human(id: "1003") { ...Name }
      }
      fragment Name on Human { name }
    )).should eq (
      {"data" => {"luke" => {"name" => "Luke Skywalker"}, "leia" => {"name" => "Leia Organa"}}}
    ).to_json
  end

  it "applies fragments whose type condition matches" do
    schema.execute(%(
      {
        luke: human(id: "1000") { ...Name ... on Human { homePlanet } }
      }
      fragment Name on Human { name }
    )).should eq (
      {"data" => {"luke" => {"name" => "Luke Skywalker", "homePlanet" => "Tatooine"}}}
    ).to_json
  end

  it "skips fragments whose type condition names another type" do
    schema.execute(%(
      {
        luke: human(id: "1000") { name ...Droid ... on Droid { primaryFunction } }
      }
      fragment Droid on Droid { primaryFunction }
    )).should eq (
      {"data" => {"luke" => {"name" => "Luke Skywalker"}}}
    ).to_json
  end

  it "reports unknown fragments" do
    schema.execute(%({ ...Missing })).should eq (
      {
        "data"   => {} of String => String,
        "errors" => [{"message" => "no fragment Missing", "locations" => [{"line" => 1, "column" => 3}], "path" => ["Missing"]}],
      }
    ).to_json
  end
end
