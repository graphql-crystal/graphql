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
  end

  @[GraphQL::InputObject]
  class NestedInputObject
    include GraphQL::InputObjectType

    getter nested_input_object : NestedInputObject?

    getter str : String?
    getter int : Int32?
    getter float : Float64?

    @[GraphQL::Field]
    def initialize(@nested_input_object : NestedInputObject?, @str : String?, @int : Int32?, @float : Float64?)
    end
  end

  @[GraphQL::Object]
  class NestedObject
    include GraphQL::ObjectType

    @nested_object : NestedObject?
    @str : String?
    @int : Int32?
    @float : Float64?

    def initialize(nested_input_object : NestedInputObject)
      @str = nested_input_object.str
      @int = nested_input_object.int
      @float = nested_input_object.float
      nested_io = nested_input_object.nested_input_object
      @nested_object = NestedObject.new(nested_io) unless nested_io.nil?
    end

    @[GraphQL::Field]
    def nested_object : NestedObject?
      @nested_object
    end

    @[GraphQL::Field]
    def str : String?
      @str
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
end
