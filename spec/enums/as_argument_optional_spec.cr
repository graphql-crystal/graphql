require "spec"
require "../../src/graphql"

module TestEnumsAsOptionalArgument
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
    def episode_to_string(episode : Episode?) : String
      return "No Episode Given" if episode.nil?

      episode.to_s
    end
  end
end

describe GraphQL::Enum do
  it "returns the correct value" do
    GraphQL::Schema.new(TestEnumsAsOptionalArgument::Query.new).execute(
      %(
        query {
          result: episodeToString
        }
      )
    ).should eq (
      {
        "data" => {
          "result" => "No Episode Given",
        },
      }
    ).to_json
  end
end
