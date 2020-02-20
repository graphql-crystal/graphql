module MutationFixture
  @[GraphQL::InputObject]
  class MutationInputObject
    include GraphQL::InputObjectType

    getter value : String

    @[GraphQL::Field]
    def initialize(@value : String)
    end
  end

  @[GraphQL::Object]
  class Mutation
    include GraphQL::ObjectType
    include GraphQL::MutationType

    @[GraphQL::Field]
    def non_null(io : MutationInputObject) : String
      io.value
    end

    @[GraphQL::Field]
    def maybe_null(io : MutationInputObject?) : String?
      io.value unless io.nil?
    end
  end
end
