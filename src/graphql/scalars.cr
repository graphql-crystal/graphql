require "big"
require "./annotations"
require "./scalar_type"

module GraphQL::Scalars
  # Descriptions were taken from Graphql.js
  # https://github.com/graphql/graphql-js/blob/main/src/type/scalars.ts

  @[Scalar(description: "The `String` scalar type represents textual data, represented as UTF-8 character sequences. The String type is most often used by GraphQL to represent free-form human-readable text.")]
  record String, value : ::String do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      new(::String.from_json(string_or_io))
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[Scalar(description: "The `Boolean` scalar type represents `true` or `false`.")]
  record Boolean, value : ::Bool do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      new(::Bool.from_json(string_or_io))
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[Scalar(description: "The `Int` scalar type represents non-fractional signed whole numeric values. Int can represent values between -(2^31) and 2^31 - 1.")]
  record Int, value : ::Int32 do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      new(::Int32.from_json(string_or_io))
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[Scalar(description: "The `Float` scalar type represents signed double-precision fractional values as specified by [IEEE 754](https://en.wikipedia.org/wiki/IEEE_floating_point).")]
  record Float, value : ::Float64 do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      new(::Float64.from_json(string_or_io))
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[Scalar(description: "The `ID` scalar type represents a unique identifier, often used to refetch an object or as key for a cache. The ID type appears in a JSON response as a String; however, it is not intended to be human-readable. When expected as an input type, any string (such as `\"4\"`) or integer (such as `4`) input value will be accepted as an ID.")]
  record ID, value : ::String do
    include GraphQL::ScalarType

    def self.from_json(string_or_io)
      case raw = JSON::Any.from_json(string_or_io).raw
      when ::String then new(raw)
      when ::Int64  then new(raw.to_s)
      else               raise ::GraphQL::TypeError.new("ID must be a String or an Int")
      end
    end

    def to_json(builder)
      builder.scalar(@value)
    end
  end

  @[Scalar]
  record BigInt, value : ::BigInt do
    include GraphQL::ScalarType

    def initialize(@value : ::BigInt)
    end

    # Accepts both integer literals and strings, since clients commonly send
    # values beyond 64 bits as strings.
    def self.from_json(string_or_io)
      pull = JSON::PullParser.new(string_or_io)
      case pull.kind
      when .int?    then new(::BigInt.new(pull.read_raw))
      when .string? then new(::BigInt.new(pull.read_string))
      else               raise ::GraphQL::TypeError.new("BigInt must be an Int or a String")
      end
    end

    def to_json(builder)
      builder.scalar(@value.to_s)
    end
  end
end
