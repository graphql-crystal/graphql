require "../../src/graphql"

module EmptyQueryFixture
  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType
  end
end
