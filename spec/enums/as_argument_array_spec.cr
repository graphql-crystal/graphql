require "spec"
require "../../src/graphql"

module TestEnumsAsArgumentArray
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
    def episodes_to_string(episodes : Array(Episode)) : String
      episodes.join(", ")
    end
  end
end

describe GraphQL::Enum do
  it "Enums generates correct schema" do
    got = GraphQL::Schema.new(TestEnumsAsArgumentArray::Query.new).document.to_s.strip
    expected = {{ read_file("spec/enums/as_argument_array.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

  it "returns the correct value" do
    GraphQL::Schema.new(TestEnumsAsArgumentArray::Query.new).execute(
      %(
        query {
          result: episodesToString(episodes: [JEDI,NEWHOPE] )
        }
      )
    ).should eq (
      {
        "data" => {
          "result" => "JEDI, NEWHOPE",
        },
      }
    ).to_json
  end
end
