require "./scalar_type"

module GraphQL
  @[Scalar(_ignore: true)]
  class ID
    include GraphQL::ScalarType

    getter value : String

    def initialize(@value)
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end
end
