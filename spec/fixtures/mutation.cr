module MutationFixture
  @[GraphQL::InputObject]
  class MutationInputObject
    include GraphQL::InputObjectType

    getter value : String

    @[GraphQL::Field]
    def initialize(@value : String)
    end
  end

  @[GraphQL::InputObject]
  class NestedMutationInputObject
    include GraphQL::InputObjectType

    getter value : NestedMutationInputObject?

    @[GraphQL::Field]
    def initialize(@value : NestedMutationInputObject?)
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

    @[GraphQL::Field]
    def nested(io : NestedMutationInputObject) : Int32
      i = 0
      current = io
      loop do
        i += 1
        if current.value.nil?
          break
        else
          current = current.value.not_nil!
        end
      end
      i
    end

    @[GraphQL::Field]
    def array(io : Array(MutationInputObject)) : Array(String)
      io.map &.value
    end
  end
end
