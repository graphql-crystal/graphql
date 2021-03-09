require "./ast"
require "./generation"

module GraphQL
  module Language
    macro define_array_cast(type)
      def self.to_{{type.id.downcase}}(value : Array) : {{type.id}}
        _values = [] of {{type.id}}
        value.each do |val|
          _values << to_{{type.id.downcase}}(val)
        end
        _values
      end

      def self.to_{{type.id.downcase}}(value) {{type.id}}
        value.as({{type.id}})
      end

      def self.to_fvalue(v : NullValue): Nil
        nil
      end

      def self.to_argumentvalue(v : NullValue): Nil
        nil
      end
    end

    # This is the AST root for normal queries
    #
    # @example Deriving a document by parsing a string
    #   document = GraphQL.parse(query_string)
    #
    class Document < ASTNode
      values({definitions: Array(OperationDefinition | FragmentDefinition | SchemaDefinition | ObjectTypeDefinition | InputObjectTypeDefinition |
                                 ScalarTypeDefinition | DirectiveDefinition | EnumTypeDefinition | InterfaceTypeDefinition | UnionTypeDefinition)})
      traverse :definitions

      def map_children(&block : ASTNode -> _)
        visited_ids = [] of UInt64
        visit(visited_ids, block)
      end

      def to_s(io : IO)
        GraphQL::Language::Generation.generate(self).to_s(io)
      end

      #  def slice_definition(name)
      #    GraphQL::Language::DefinitionSlice.slice(self, name)
      #  end
    end

    class SchemaDefinition < ASTNode
      values({query: String, mutation: String?, subscription: String?})
    end

    # A query, mutation or subscription.
    # May be anonymous or named.
    # May be explicitly typed (eg `mutation { ... }`) or implicitly a query (eg `{ ... }`).
    class OperationDefinition < ASTNode
      values(
        {
          operation_type: String,
          name:           String?,
          variables:      Array(VariableDefinition),
          directives:     Array(Directive),
          selections:     Array(Selection),
        }
      )
      traverse :variables, :directives, :selections
    end

    class DirectiveDefinition < ASTNode
      values({name: String, arguments: Array(InputValueDefinition), locations: Array(String), description: String?})
      traverse :arguments
    end

    class Directive < ASTNode
      values({name: String, arguments: Array(Argument)})
      traverse :arguments
    end

    alias FValue = String | Int32 | Float64 | Bool | Nil | AEnum | InputObject | Array(FValue) | Hash(String, FValue)

    define_array_cast(FValue)

    alias Type = TypeName | NonNullType | ListType
    alias Selection = Field | FragmentSpread | InlineFragment

    class VariableDefinition < ASTNode
      values({name: String, type: Type, default_value: FValue})
      traverse :type
    end

    alias ArgumentValue = FValue | InputObject | VariableIdentifier | Array(ArgumentValue)

    define_array_cast(ArgumentValue)

    class Argument < ASTNode
      values({name: String, value: ArgumentValue})

      def to_value
        value
      end
    end

    class TypeDefinition < ASTNode
      values({name: String, description: String?})
    end

    class ScalarTypeDefinition < TypeDefinition
      values({directives: Array(Directive)})
      traverse :directives
    end

    class ObjectTypeDefinition < TypeDefinition
      values(
        {interfaces: Array(String),
         fields:     Array(FieldDefinition),
         directives: Array(Directive)}
      )
      traverse :fields, :directives
    end

    class InputObjectTypeDefinition < TypeDefinition
      values({fields: Array(InputValueDefinition), directives: Array(Directive)})
      traverse :fields, :directives
    end

    class InputValueDefinition < ASTNode
      values({name: String, type: Type, default_value: FValue, directives: Array(Directive), description: String?})
      traverse :type, :directives
    end

    # Base class for nodes whose only value is a name (no child nodes or other scalars)
    class NameOnlyNode < ASTNode
      values({name: String})
    end

    # Base class for non-null type names and list type names
    class WrapperType < ASTNode
      values({of_type: (Type)})
      traverse :of_type
    end

    # A type name, used for variable definitions
    class TypeName < NameOnlyNode; end

    # A list type definition, denoted with `[...]` (used for variable type definitions)
    class ListType < WrapperType; end

    # A collection of key-value inputs which may be a field argument

    class InputObject < ASTNode
      values({arguments: Array(Argument)})
      traverse :arguments

      # @return [Hash<String, Any>] Recursively turn this input object into a Ruby Hash
      def to_h
        arguments.reduce({} of String => FValue) do |memo, pair|
          v = pair.value
          memo[pair.name] = case v
                            when InputObject
                              v.to_h
                            when Array
                              v.map { |v| v.as(FValue) }
                            else
                              v
                            end.as(FValue)
          memo
        end
      end

      def to_value
        to_h
      end
    end

    # A non-null type definition, denoted with `...!` (used for variable type definitions)
    class NonNullType < WrapperType; end

    # An enum value. The string is available as {#name}.
    class AEnum < NameOnlyNode
      def to_value
        name
      end
    end

    # A null value literal.
    class NullValue < NameOnlyNode; end

    class VariableIdentifier < NameOnlyNode; end

    # A single selection in a
    # A single selection in a GraphQL query.
    class Field < ASTNode
      values({
        name:       String,
        _alias:     String?,
        arguments:  Array(Argument),
        directives: Array(Directive),
        selections: Array(Selection),
      })
      traverse :arguments, :directives, :selections
    end

    class FragmentDefinition < ASTNode
      values({
        name:       String?,
        type:       Type,
        directives: Array(Directive),
        selections: Array(Selection),
      })
      traverse :type, :directives, :selections
    end

    class FieldDefinition < ASTNode
      values({name: String, arguments: Array(InputValueDefinition), type: Type, directives: Array(Directive), description: String?})
      traverse :type, :arguments, :directives
    end

    class InterfaceTypeDefinition < TypeDefinition
      values({fields: Array(FieldDefinition), directives: Array(Directive)})
      traverse :fields, :directives
    end

    class UnionTypeDefinition < TypeDefinition
      values({types: Array(TypeName), directives: Array(Directive)})
      traverse :types, :directives
    end

    class EnumTypeDefinition < TypeDefinition
      values({fvalues: Array(EnumValueDefinition), directives: Array(Directive)})
      traverse :directives
    end

    # Application of a named fragment in a selection
    class FragmentSpread < ASTNode
      values({name: String, directives: Array(Directive)})
      traverse :directives
    end

    # An unnamed fragment, defined directly in the query with `... {  }`
    class InlineFragment < ASTNode
      values({type: Type?, directives: Array(Directive), selections: Array(Selection)})
      traverse :type, :directives, :selections
    end

    class EnumValueDefinition < ASTNode
      values({name: String, directives: Array(Directive), selection: Array(Selection)?, description: String?})
      traverse :directives
    end
  end
end
