require "spec"
require "../../src/graphql"

module TestEnumsAsInputArgument
  @[GraphQL::Enum(description: "List of Starwars episodes")]
  enum Episode
    NEWHOPE
    EMPIRE
    JEDI
  end

  @[GraphQL::InputObject]
  class MyInput
    include GraphQL::InputObjectType

    getter my_enum

    @[GraphQL::Field]
    def initialize(@my_enum : Episode)
    end
  end

  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType

    @[GraphQL::Field]
    def episodes_to_string(episode : MyInput) : String
      episode.my_enum.to_s
    end
  end
end

class GraphqlRequest
  include JSON::Serializable

  @[JSON::Field(key: "variables")]
  property variables : Hash(String, JSON::Any)?
end

describe GraphQL::Enum do
  it "returns the correct value" do
    GraphQL::Schema.new(TestEnumsAsInputArgument::Query.new).execute(
      %(
        query {
          result: episodesToString(episode: {myEnum: "JEDI"} )
        }
      )
    ).should eq (
      {
        "data" => {
          "result" => "JEDI",
        },
      }
    ).to_json
  end
end
