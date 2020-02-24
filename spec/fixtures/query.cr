module QueryFixture
  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType

    @[GraphQL::Field(name: "ann_ks", description: "Annotations", arguments: {
      arg_with_descr: {description: "arg_with_descr description"},
      arg_with_name: {name: "argWithNameOverride"},
      arg_with_both: {name: "argWithBothOverride", description: "arg_with_both description"},
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
  end
end