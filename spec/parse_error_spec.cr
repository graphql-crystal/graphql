require "./spec_helper"

describe "parse errors" do
  schema = GraphQL::Schema.new(StarWars::Query.new)

  it "returns syntax errors in the response instead of raising" do
    schema.execute(%[{ human(id: "1000" }]).should eq ( # ameba:disable Style/PercentLiteralDelimiters
{"errors" => [{"message" => "Expected Name, found BRACE_R "}]}
      ).to_json
  end

  it "returns lexer errors in the response instead of raising" do
    schema.execute(%({ human(id: "1000) { name } })).should eq (
      {"errors" => [{"message" => "Unterminated string."}]}
    ).to_json
  end

  it "rejects unsupported operation types" do
    schema.execute(%(subscription { human(id: "1000") { name } })).should eq (
      {"errors" => [{"message" => "subscription operations must be started with Schema#subscribe"}]}
    ).to_json
  end
end
