require "./spec_helper"

module InstanceVarFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    property prop : String?

    @[GraphQL::Field]
    getter getter : String?

    @[GraphQL::Field]
    property q : Query?

    def initialize(@prop, @getter, @q)
    end
  end
end

describe GraphQL do
  it "resolves instance vars" do
    schema = GraphQL::Schema.new(InstanceVarFixture::Query.new("123", "foo", InstanceVarFixture::Query.new("321", nil, nil)))

    schema.execute(%(
      {
        prop
        getter
        q {
          prop
        }
      }
    )).should eq (
      {
        "data" => {
          "prop" => "123",
          "getter" => "foo",
          "q" => {
            "prop": "321",
          }
        },
      }
    ).to_json
  end
end
