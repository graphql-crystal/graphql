require "../../src/graphql"

module BaseClassesFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def hello_world : String
      "hello world"
    end
  end

  @[GraphQL::Object]
  class Mutation < GraphQL::BaseMutation
    @[GraphQL::Field]
    def hello_world : String
      "hello world"
    end
  end

  @[GraphQL::Object]
  class Object < GraphQL::BaseObject
    @[GraphQL::Field]
    def hello_world : String
      "hello world"
    end
  end
end
