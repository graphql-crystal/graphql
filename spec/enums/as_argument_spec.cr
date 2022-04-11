require "spec"
require "../../src/graphql"

module TestEnumsAsArgument
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
    def episode_to_string(episode : Episode) : String?
      episode.to_s
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
    GraphQL::Schema.new(TestEnumsAsArgument::Query.new).execute(
      %(
        query {
          result: episodeToString(episode: JEDI)
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

  it "returns the correct value with variable" do
    request = {"variables" => {"e" => "EMPIRE"}}.to_json

    graphql_request = GraphqlRequest.from_json(request)

    GraphQL::Schema.new(TestEnumsAsArgument::Query.new).execute(
      %(
        query($e: Episode!) {
          result: episodeToString(episode: $e)
        }
      ),
      graphql_request.variables
    ).should eq (
      {
        "data" => {
          "result" => "EMPIRE",
        },
      }
    ).to_json
  end
end
