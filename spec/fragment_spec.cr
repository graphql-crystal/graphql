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

  it "reports unknown fragments" do
    schema.execute(%({ ...Missing })).should eq (
      {
        "data"   => {} of String => String,
        "errors" => [{"message" => "no fragment Missing", "path" => ["Missing"]}],
      }
    ).to_json
  end
end
