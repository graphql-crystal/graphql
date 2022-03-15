require "./annotations"
require "./object_type"
require "./query_type"

module GraphQL
  module Introspection
    @[GraphQL::Object(name: "__Schema")]
    class Schema
      include GraphQL::ObjectType

      @document : Language::Document
      @query_type : String
      @mutation_type : String?

      def initialize(@document, @query_type, @mutation_type)
      end

      @[GraphQL::Field]
      def types : Array(GraphQL::Introspection::Type)
        @document.definitions.select { |d| d.is_a? Language::TypeDefinition }.map { |d| Type.new @document, d.as(Language::TypeDefinition) }
      end

      @[GraphQL::Field]
      def query_type : GraphQL::Introspection::Type
        Type.new @document, @document.definitions.find { |d|
          d.is_a?(Language::TypeDefinition) && d.name == @query_type
        }.not_nil!.as(Language::TypeDefinition)
      end

      @[GraphQL::Field]
      def mutation_type : GraphQL::Introspection::Type?
        if mt = @mutation_type
          Type.new @document, @document.definitions.find { |d|
            d.is_a?(Language::TypeDefinition) && d.name == mt
          }.not_nil!.as(Language::TypeDefinition)
        else
          nil
        end
      end

      @[GraphQL::Field]
      def subscription_type : GraphQL::Introspection::Type?
        nil
      end

      @[GraphQL::Field]
      def directives : Array(GraphQL::Introspection::Directive)
        [
          GraphQL::Introspection::Directive.new(
            @document,
            Language::DirectiveDefinition.new(
              name: "skip",
              description: nil,
              locations: [
                DirectiveLocation::FIELD.to_s,
                DirectiveLocation::FRAGMENT_SPREAD.to_s,
                DirectiveLocation::INLINE_FRAGMENT.to_s,
              ],
              arguments: [
                Language::InputValueDefinition.new(
                  name: "if",
                  type: Language::NonNullType.new(of_type: Language::TypeName.new(name: "Boolean")),
                  default_value: nil,
                  directives: [] of GraphQL::Language::Directive,
                  description: nil,
                ),
              ]
            )
          ),
          GraphQL::Introspection::Directive.new(
            @document,
            Language::DirectiveDefinition.new(
              name: "include",
              description: nil,
              locations: [
                DirectiveLocation::FIELD.to_s,
                DirectiveLocation::FRAGMENT_SPREAD.to_s,
                DirectiveLocation::INLINE_FRAGMENT.to_s,
              ],
              arguments: [
                Language::InputValueDefinition.new(
                  name: "if",
                  type: Language::NonNullType.new(of_type: Language::TypeName.new(name: "Boolean")),
                  default_value: nil,
                  directives: [] of GraphQL::Language::Directive,
                  description: nil,
                ),
              ]
            )
          ),
          GraphQL::Introspection::Directive.new(
            @document,
            Language::DirectiveDefinition.new(
              name: "deprecated",
              description: nil,
              locations: [
                DirectiveLocation::FIELD_DEFINITION.to_s,
                DirectiveLocation::ENUM_VALUE.to_s,
              ],
              arguments: [
                Language::InputValueDefinition.new(
                  name: "reason",
                  type: Language::TypeName.new(name: "String"),
                  default_value: nil,
                  directives: [] of GraphQL::Language::Directive,
                  description: nil,
                ),
              ]
            )
          ),
        ] of GraphQL::Introspection::Directive
      end
    end

    @[GraphQL::Object(name: "__Type")]
    class Type
      include GraphQL::ObjectType

      @document : Language::Document
      @definition : Language::TypeDefinition | Language::WrapperType

      def self.from_ast(document : Language::Document, type : Language::ASTNode)
        case type
        when Language::TypeName
          self.new(document, document.definitions.find { |d| d.is_a? Language::TypeDefinition && d.name == type.name }.not_nil!.as(Language::TypeDefinition))
        when Language::TypeDefinition, Language::WrapperType
          self.new(document, type)
        else
          raise GraphQL::TypeError.new("cannot create type from #{type}")
        end
      end

      def initialize(@document, @definition : Language::TypeDefinition | Language::WrapperType)
      end

      @[GraphQL::Field]
      def kind : GraphQL::Introspection::TypeKind
        case @definition
        when Language::ObjectTypeDefinition
          TypeKind::OBJECT
        when Language::InputObjectTypeDefinition
          TypeKind::INPUT_OBJECT
        when Language::ScalarTypeDefinition
          TypeKind::SCALAR
        when Language::EnumTypeDefinition
          TypeKind::ENUM
        when Language::InterfaceTypeDefinition
          TypeKind::INTERFACE
        when Language::UnionTypeDefinition
          TypeKind::UNION
        when Language::NonNullType
          TypeKind::NON_NULL
        when Language::ListType
          TypeKind::LIST
        else
          raise GraphQL::TypeError.new("could not match any type")
        end
      end

      @[GraphQL::Field]
      def name : String?
        case definition = @definition
        when Language::ObjectTypeDefinition
          definition.name
        when Language::InputObjectTypeDefinition
          definition.name
        when Language::ScalarTypeDefinition
          definition.name
        when Language::EnumTypeDefinition
          definition.name
        when Language::InterfaceTypeDefinition
          definition.name
        when Language::UnionTypeDefinition
          definition.name
        else
          nil
        end
      end

      @[GraphQL::Field]
      def description : String?
        case definition = @definition
        when Language::ObjectTypeDefinition
          definition.description
        when Language::InputObjectTypeDefinition
          definition.description
        when Language::ScalarTypeDefinition
          definition.description
        when Language::EnumTypeDefinition
          definition.description
        when Language::InterfaceTypeDefinition
          definition.description
        when Language::UnionTypeDefinition
          definition.description
        when Language::NonNullType
          nil
        when Language::ListType
          nil
        end
      end

      # OBJECT and INTERFACE only
      @[GraphQL::Field]
      def fields(include_deprecated : Bool = false) : Array(GraphQL::Introspection::Field)?
        case definition = @definition
        when Language::ObjectTypeDefinition
          definition.fields.select { |f|
            if include_deprecated
              true
            else
              f.directives.find { |d| d.name == "deprecated" }.nil?
            end
          }.map { |f|
            GraphQL::Introspection::Field.new(@document, f.as(Language::FieldDefinition))
          }
        when Language::InterfaceTypeDefinition # why can't we put this above?
          definition.fields.map { |f| GraphQL::Introspection::Field.new(@document, f.as(Language::FieldDefinition)) }
        else
          nil
        end
      end

      # OBJECT only
      @[GraphQL::Field]
      def interfaces : Array(GraphQL::Introspection::Type)?
        case definition = @definition
        when Language::ObjectTypeDefinition
          [] of GraphQL::Introspection::Type
        else
          nil
        end
      end

      # INTERFACE and UNION only
      @[GraphQL::Field]
      def possible_types : Array(GraphQL::Introspection::Type)?
        case definition = @definition
        when Language::InterfaceTypeDefinition, Language::UnionTypeDefinition
          [] of GraphQL::Introspection::Type
        else
          nil
        end
      end

      # ENUM only
      @[GraphQL::Field]
      def enum_values(include_deprecated : Bool = false) : Array(GraphQL::Introspection::EnumValue)?
        case definition = @definition
        when Language::EnumTypeDefinition
          definition.fvalues.select { |v|
            if include_deprecated
              true
            else
              v.directives.find { |d| d.name == "deprecated" }.nil?
            end
          }.map { |v| EnumValue.new(@document, v) }
        else
          nil
        end
      end

      # INPUT_OBJECT only
      @[GraphQL::Field]
      def input_fields : Array(GraphQL::Introspection::InputValue)?
        case definition = @definition
        when Language::InputObjectTypeDefinition
          definition.fields.map { |f| GraphQL::Introspection::InputValue.new(@document, f.as(Language::InputValueDefinition)) }
        else
          nil
        end
      end

      # NON_NULL and LIST only
      @[GraphQL::Field]
      def of_type : GraphQL::Introspection::Type?
        case definition = @definition
        when Language::NonNullType, Language::ListType
          Type.from_ast(@document, definition.of_type)
        else
          nil
        end
      end
    end

    @[GraphQL::Object(name: "__Field")]
    class Field
      include GraphQL::ObjectType

      @document : GraphQL::Language::Document
      @definition : GraphQL::Language::FieldDefinition

      def initialize(@document, @definition)
      end

      # NON_NULL and LIST only
      @[GraphQL::Field]
      def name : String
        @definition.name
      end

      @[GraphQL::Field]
      def description : String?
        @definition.description
      end

      @[GraphQL::Field]
      def args : Array(GraphQL::Introspection::InputValue)
        @definition.arguments.map { |m| InputValue.new(@document, m) }
      end

      @[GraphQL::Field]
      def type : GraphQL::Introspection::Type
        GraphQL::Introspection::Type.from_ast(@document, @definition.type)
      end

      @[GraphQL::Field]
      def is_deprecated : Bool
        !@definition.directives.find { |d| d.name == "deprecated" }.nil?
      end

      @[GraphQL::Field]
      def deprecation_reason : String?
        if directive = @definition.directives.find { |d| d.name == "deprecated" }
          if argument = directive.arguments.find { |d| d.name == "reason" }
            argument.value.as(String)
          end
        end
      end
    end

    @[GraphQL::Object(name: "__InputValue")]
    class InputValue
      include GraphQL::ObjectType

      @document : Language::Document
      @definition : Language::InputValueDefinition

      def initialize(@document, @definition)
      end

      @[GraphQL::Field]
      def name : String
        @definition.name
      end

      @[GraphQL::Field]
      def description : String?
        @definition.description
      end

      @[GraphQL::Field]
      def type : GraphQL::Introspection::Type
        GraphQL::Introspection::Type.from_ast(@document, @definition.type)
      end

      @[GraphQL::Field]
      def default_value : String?
        Language::Generation.generate(@definition.default_value) unless @definition.default_value.nil?
      end
    end

    @[GraphQL::Object(name: "__EnumValue")]
    class EnumValue
      include GraphQL::ObjectType

      @document : Language::Document
      @definition : Language::EnumValueDefinition

      def initialize(@document, @definition)
      end

      @[GraphQL::Field]
      def name : String
        @definition.name
      end

      @[GraphQL::Field]
      def description : String?
        @definition.description
      end

      @[GraphQL::Field]
      def is_deprecated : Bool
        !@definition.directives.find { |d| d.name == "deprecated" }.nil?
      end

      @[GraphQL::Field]
      def deprecation_reason : String?
        if directive = @definition.directives.find { |d| d.name == "deprecated" }
          if argument = directive.arguments.find { |d| d.name == "reason" }
            argument.value.as(String)
          end
        end
      end
    end

    @[GraphQL::Object(name: "__Directive")]
    class Directive
      include GraphQL::ObjectType

      @document : Language::Document
      @definition : Language::DirectiveDefinition

      def initialize(@document, @definition)
      end

      @[GraphQL::Field]
      def name : String
        @definition.name
      end

      @[GraphQL::Field]
      def description : String?
        @definition.description
      end

      @[GraphQL::Field]
      def locations : Array(String)
        @definition.locations
      end

      @[GraphQL::Field]
      def args : Array(GraphQL::Introspection::InputValue)
        @definition.arguments.map { |a| InputValue.new(@document, a) }
      end
    end

    @[GraphQL::Enum(name: "__TypeKind")]
    enum TypeKind
      SCALAR
      OBJECT
      INTERFACE
      UNION
      ENUM
      INPUT_OBJECT
      LIST
      NON_NULL
    end

    @[GraphQL::Enum(name: "__DirectiveLocation")]
    enum DirectiveLocation
      QUERY
      MUTATION
      SUBSCRIPTION
      FIELD
      FRAGMENT_DEFINITION
      FRAGMENT_SPREAD
      INLINE_FRAGMENT
      SCHEMA
      SCALAR
      OBJECT
      FIELD_DEFINITION
      ARGUMENT_DEFINITION
      INTERFACE
      UNION
      ENUM
      ENUM_VALUE
      INPUT_OBJECT
      INPUT_FIELD_DEFINITION
    end
  end
end
