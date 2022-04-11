require "spec"
require "../../src/graphql"

module TestEnumsAsDefaultArgument
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
    def episode_to_string(episode : Episode? = Episode::EMPIRE) : String
      episode.to_s
    end
  end
end

describe GraphQL::Enum do
  it "returns the correct value" do
    GraphQL::Schema.new(TestEnumsAsDefaultArgument::Query.new).execute(
      %(
        query {
          result: episodeToString
        }
      )
    ).should eq (
      {
        "data" => {
          "result" => "EMPIRE",
        },
      }
    ).to_json
  end
end
