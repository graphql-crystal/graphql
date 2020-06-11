require "./spec_helper"

describe GraphQL::MutationType do
  it "takes non-null input" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
      mutation Mutation {
        value: nonNull(io: {value: "123"})
      }
    )).should eq (
      {
        "data" => {
          "value" => "123",
        },
      }
    ).to_json
  end

  it "takes null input" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
      mutation Mutation {
        value: maybeNull
      }
    )).should eq (
      {
        "data" => {
          "value" => nil,
        },
      }
    ).to_json
  end

  it "takes array of strings" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : [MutationInputObject]) {
          value: array(strings: ["one", "two", $three])
        }
      ),
      {"three" => JSON::Any.new("three")} of String => JSON::Any
    ).should eq (
      {
        "data" => {"value" => ["one", "two", "three"]},
      }
    ).to_json
  end

  it "takes array of ints" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : [MutationInputObject]) {
          value: array(ints: [1, 2, $three])
        }
      ),
      {"three" => JSON::Any.new(3_i64)} of String => JSON::Any
    ).should eq (
      {
        "data" => {"value" => ["1", "2", "3"]},
      }
    ).to_json
  end

  it "takes array of floats" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : [MutationInputObject]) {
          value: array(floats: [1.0, 2.0, $three])
        }
      ),
      {"three" => JSON::Any.new(3_i64)} of String => JSON::Any
    ).should eq (
      {
        "data" => {"value" => ["1.0", "2.0", "3.0"]},
      }
    ).to_json
  end

  it "takes input object as variable" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : MutationInputObject) {
          value: nonNull(io: $obj)
        }
      ),
      {"obj" => JSON::Any.new({"value" => JSON::Any.new("123")})} of String => JSON::Any
    ).should eq (
      {
        "data" => {
          "value" => "123",
        },
      }
    ).to_json
  end

  it "takes nested input objects" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : MutationInputObject) {
          value: nested(io: $obj)
        }
      ),
      JSON.parse({"obj" => {"value" => {"value" => {"value" => nil}}}}.to_json).raw.as(Hash(String, JSON::Any))
    ).should eq (
      {
        "data" => {
          "value" => 3,
        },
      }
    ).to_json
  end

  it "takes nested input objects with variable" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : NestedInputObject) {
          value: nested(io: { value: { value: $obj }})
        }
      ),
      JSON.parse({"obj" => {"value" => nil}}.to_json).raw.as(Hash(String, JSON::Any))
    ).should eq (
      {
        "data" => {
          "value" => 3,
        },
      }
    ).to_json
  end

  it "takes input array as variable" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($obj : [MutationInputObject]) {
          value: array(io: $obj)
        }
      ),
      JSON.parse({"obj" => [{"value" => "123"}, {"value" => "321"}]}.to_json).raw.as(Hash(String, JSON::Any))
    ).should eq (
      {
        "data" => {"value" => ["123", "321"]},
      }
    ).to_json
  end

  it "takes variable in object" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
        mutation Mutation($value1 : String, $value2 : String) {
          value: array(io: [{value: $value1}, {value: $value2}])
        }
      ),
      JSON.parse({"value1" => "123", "value2" => "321"}.to_json).raw.as(Hash(String, JSON::Any))
    ).should eq (
      {
        "data" => {"value" => ["123", "321"]},
      }
    ).to_json
  end

  it "returns error when null is passed to non-null" do
    GraphQL::Schema.new(StarWars::Query.new, MutationFixture::Mutation.new).execute(%(
      mutation Mutation {
        value: nonNull
      }
    )).should eq (
      {
        "data"   => {} of Nil => Nil,
        "errors" => [
          {"message" => "missing required argument io", "path" => ["value"]},
        ],
      }
    ).to_json
  end
end
