require "spec"
require "../../src/graphql"

module TestEnumsAsReturn
  @[GraphQL::Enum(description: "List of Starwars episodes")]
  enum Episode
    NEWHOPE
    EMPIRE
    JEDI
  end

  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType

    @[GraphQL::Field]
    def a_episode : Episode
      Episode::NEWHOPE
    end
  end
end

describe GraphQL::Enum do
  it "returns the correct value" do
    GraphQL::Schema.new(TestEnumsAsReturn::Query.new).execute(
      %(
        query { aEpisode }
      )
    ).should eq (
      {
        "data" => {
          "aEpisode" => "NEWHOPE",
        },
      }
    ).to_json
  end
end
