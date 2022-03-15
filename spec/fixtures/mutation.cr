require "../../src/graphql"

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
        if value = current.value
          current = value
        else
          break
        end
      end
      i
    end

    @[GraphQL::Field]
    def array(io : Array(MutationInputObject)?, strings : Array(String)?, ints : Array(Int32)?, floats : Array(Float64)?) : Array(String)
      return io.map &.value unless io.nil?
      return strings unless strings.nil?
      return ints.map &.to_s unless ints.nil?
      floats.not_nil!.map &.to_s
    end
  end
end
