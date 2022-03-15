require "../../src/graphql"

module QueryFixture
  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType

    @[GraphQL::Field(name: "ann_ks", description: "Annotations", arguments: {
      arg_with_descr: {description: "arg_with_descr description"},
      arg_with_name:  {name: "argWithNameOverride"},
      arg_with_both:  {name: "argWithBothOverride", description: "arg_with_both description"},
    })]
    def annotation_kitchen_sink(arg_with_descr : String, arg_with_name : String, arg_with_both : String, arg_with_none : String) : String
      ""
    end

    @[GraphQL::Field]
    def args_without_annotations(arg1 : String, arg2 : String, arg3 : String) : String
      ""
    end

    @[GraphQL::Field]
    def args_default_values(arg1 : String = "Default", arg2 : Int32 = 123, arg3 : Float64 = 1.23) : String
      ""
    end

    @[GraphQL::Field]
    def echo_nested_input_object(nested_input_object : NestedInputObject) : NestedObject
      NestedObject.new(nested_input_object)
    end

    @[GraphQL::Field]
    def default_values(int : Int32 = 1, float : Float64 = 2.0, emptyStr : String = "", str : String = "qwe", bool : Bool = false) : String
      ""
    end

    @[GraphQL::Field]
    def record(value : String) : RecordResolver
      RecordResolver.new(value)
    end
  end

  @[GraphQL::InputObject]
  class NestedInputObject
    include GraphQL::InputObjectType

    getter object : NestedInputObject?
    getter array : Array(NestedInputObject)?
    getter str : String?
    getter int : Int32?
    getter float : Float64?

    @[GraphQL::Field]
    def initialize(@object : NestedInputObject?, @array : Array(NestedInputObject)?, @str : String?, @int : Int32?, @float : Float64?)
    end
  end

  @[GraphQL::Object]
  class NestedObject
    include GraphQL::ObjectType

    @object : NestedObject?
    @array : Array(NestedObject)?
    @str : String?
    @int : Int32?
    @float : Float64?

    def initialize(object : NestedInputObject)
      @object = NestedObject.new(object.object.not_nil!) unless object.object.nil?
      @array = object.array.not_nil!.map { |io| NestedObject.new(io).as(NestedObject) }.as(Array(NestedObject) | Nil) unless object.array.nil?
      @str = object.str
      @int = object.int
      @float = object.float
    end

    @[GraphQL::Field]
    def object : NestedObject?
      @object
    end

    @[GraphQL::Field]
    def array : Array(NestedObject)?
      @array
    end

    @[GraphQL::Field]
    def str : String?
      @str
    end

    @[GraphQL::Field]
    def str_reverse : ReverseStringScalar?
      if str = @str
        ReverseStringScalar.new(str)
      end
    end

    @[GraphQL::Field]
    def id : GraphQL::Scalars::ID?
      if str = @str
        GraphQL::Scalars::ID.new(str)
      end
    end

    @[GraphQL::Field]
    def int : Int32?
      @int
    end

    @[GraphQL::Field]
    def float : Float64?
      @float
    end
  end

  @[GraphQL::Scalar]
  class ReverseStringScalar
    include GraphQL::ScalarType

    @value : String

    def initialize(@value)
    end

    def to_json(builder : JSON::Builder)
      builder.scalar(@value.reverse)
    end
  end

  @[GraphQL::Object(description: "RecordResolver description")]
  record RecordResolver, value : ::String do
    include GraphQL::ObjectType

    @[GraphQL::Field]
    def value : String
      @value
    end
  end
end
