require "./spec_helper"

describe "complexity" do
  schema = GraphQL::Schema.new(StarWars::Query.new)
  query = %(
    {
      luke: human(id: "1000") { name ...Planet }
      ... { leia: human(id: "1003") { name } }
    }
    fragment Planet on Human { homePlanet }
  )

  it "counts the selected fields with fragments expanded" do
    ctx = GraphQL::Context.new
    schema.execute(query, context: ctx)
    ctx.complexity.should eq 5
  end

  it "executes an operation within the limit" do
    ctx = GraphQL::Context.new
    ctx.max_complexity = 5
    schema.execute(query, context: ctx).should eq (
      {
        "data" => {
          "luke" => {"name" => "Luke Skywalker", "homePlanet" => "Tatooine"},
          "leia" => {"name" => "Leia Organa"},
        },
      }
    ).to_json
  end

  it "rejects an operation over the limit without resolving anything" do
    ctx = GraphQL::Context.new
    ctx.max_complexity = 4
    schema.execute(query, context: ctx).should eq (
      {"errors" => [{"message" => "operation complexity 5 exceeds the maximum of 4", "path" => [] of String}]}
    ).to_json
    ctx.complexity.should eq 5
  end

  it "counts a cyclic fragment once" do
    ctx = GraphQL::Context.new
    ctx.max_complexity = 10
    schema.execute(%({ ...Loop } fragment Loop on Query { luke: human(id: "1000") { name } ...Loop }), context: ctx)
    ctx.complexity.should eq 2
  end
end
