require "./spec_helper"

describe "@skip and @include" do
  schema = GraphQL::Schema.new(StarWars::Query.new)
  luke = {"data" => {"luke" => {"name" => "Luke Skywalker"}}}.to_json

  it "skips and includes with literals" do
    schema.execute(%({
      luke: human(id: "1000") { name }
      leia: human(id: "1003") @skip(if: true) { name }
      han: human(id: "1002") @include(if: false) { name }
    })).should eq luke
  end

  it "skips and includes with variables" do
    schema.execute(%(query ($yes: Boolean!, $no: Boolean!) {
      luke: human(id: "1000") @include(if: $yes) { name }
      leia: human(id: "1003") @skip(if: $yes) { name }
      han: human(id: "1002") @include(if: $no) { name }
    }), {"yes" => JSON::Any.new(true), "no" => JSON::Any.new(false)}).should eq luke
  end

  it "reports a non-boolean argument instead of raising" do
    schema.execute(%({
      luke: human(id: "1000") { name }
      leia: human(id: "1003") @skip(if: 1) { name }
    })).should eq (
      {
        "data"   => {"luke" => {"name" => "Luke Skywalker"}},
        "errors" => [{"message" => "argument if of directive @skip must be a Boolean", "locations" => [{"line" => 3, "column" => 7}], "path" => ["leia"]}],
      }
    ).to_json
  end

  it "reports a null variable instead of raising" do
    schema.execute(%(query ($s: Boolean) {
      luke: human(id: "1000") { name }
      leia: human(id: "1003") @include(if: $s) { name }
    })).should eq (
      {
        "data"   => {"luke" => {"name" => "Luke Skywalker"}},
        "errors" => [{"message" => "argument if of directive @include must be a Boolean", "locations" => [{"line" => 3, "column" => 7}], "path" => ["leia"]}],
      }
    ).to_json
  end

  it "reports a missing if argument" do
    schema.execute(%({
      luke: human(id: "1000") { name }
      ...Leia @skip
    }
    fragment Leia on Query { leia: human(id: "1003") { name } })).should eq (
      {
        "data"   => {"luke" => {"name" => "Luke Skywalker"}},
        "errors" => [{"message" => "directive @skip requires argument if", "locations" => [{"line" => 3, "column" => 7}], "path" => ["Leia"]}],
      }
    ).to_json
  end
end
