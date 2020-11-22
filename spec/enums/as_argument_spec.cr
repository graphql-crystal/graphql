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
  it "Enums generates correct schema" do
    got = GraphQL::Schema.new(TestEnumsAsArgument::Query.new).document.to_s.strip
    expected = {{ read_file("spec/enums/as_argument.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

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
