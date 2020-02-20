require "./spec_helper"

describe GraphQL::MutationType do
  it "Takes non-null input" do
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

  it "Takes null input" do
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

  it "Returns error when null is passed to non-null" do
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
