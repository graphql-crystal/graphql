require "spec"
require "../../src/graphql"

module TestEnumsAsReturnOptional
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
  it "Enums generates correct schema" do
    got = GraphQL::Schema.new(TestEnumsAsReturnOptional::Query.new).document.to_s.strip
    expected = {{ read_file("spec/enums/as_return_optional.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end
end
