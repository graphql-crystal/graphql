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
  it "Enums generates correct schema for default arguments" do
    got = GraphQL::Schema.new(TestEnumsAsDefaultArgument::Query.new).document.to_s.strip
    expected = {{ read_file("spec/enums/as_argument_default.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

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
