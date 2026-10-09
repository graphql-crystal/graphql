require "./language"
require "./query_type"
require "./mutation_type"

module GraphQL
  class Schema
    getter document : Language::Document
    @query : QueryType
    @mutation : MutationType?

    # convert JSON value to FValue
    private def to_fvalue(any : JSON::Any) : Language::FValue
      case raw = any.raw
      when Int64
        raw.to_i32.as(Language::FValue)
      when Hash
        args = raw.map do |key, value|
          Language::Argument.new(key, to_fvalue(value))
        end
        Language::InputObject.new(args)
      when Array
        raw.map do |value|
          to_fvalue(value)
        end
      else
        raw.as(Language::FValue)
      end
    end

    # Resolves the value of every variable the operation declares: the value
    # sent by the client, else the default from the declaration, else `nil`
    # for nullable variables. Variables the operation uses without declaring
    # them are looked up directly in `variables` when substituted.
    private def resolve_variables(operation : Language::OperationDefinition, variables : Hash(String, JSON::Any)?, errors) : Hash(String, Language::FValue)
      resolved = Hash(String, Language::FValue).new

      operation.variables.each do |definition|
        name = definition.name
        if variables && variables.has_key?(name)
          begin
            resolved[name] = to_fvalue(variables[name])
          rescue ex
            errors << Error.new("invalid value for variable #{name}: #{ex.message}", [] of String | Int32)
            resolved[name] = nil
          end
        elsif !definition.default_value.nil?
          resolved[name] = definition.default_value
        elsif definition.type.is_a?(Language::NonNullType)
          errors << Error.new("missing required variable #{name}", [] of String | Int32)
          resolved[name] = nil
        else
          resolved[name] = nil
        end
      end

      resolved
    end

    private def variable_value(identifier : Language::VariableIdentifier, resolved, variables, errors) : Language::FValue
      name = identifier.name
      if resolved.has_key?(name)
        resolved[name]
      elsif variables && variables.has_key?(name)
        begin
          to_fvalue(variables[name])
        rescue ex
          errors << Error.new("invalid value for variable #{name}: #{ex.message}", [] of String | Int32)
          nil
        end
      else
        errors << Error.new("missing variable #{name}", [] of String | Int32)
        nil
      end
    end

    private def substitute_variables(node, resolved, variables, errors)
      case node
      when Language::Argument
        case value = node.value
        when Language::VariableIdentifier
          node.value = variable_value(value, resolved, variables, errors)
        when Array
          value.each_with_index do |val, i|
            case val
            when Language::VariableIdentifier
              value[i] = variable_value(val, resolved, variables, errors)
            else
              substitute_variables(val, resolved, variables, errors)
            end
          end
        when Language::InputObject
          value.arguments.each do |arg|
            substitute_variables(arg, resolved, variables, errors)
          end
        else
          nil
        end
      when Language::InputObject
        node.arguments.each do |arg|
          substitute_variables(arg, resolved, variables, errors)
        end
      else
        nil
      end
    end

    # Counts the fields an operation selects, following fragment spreads and
    # inline fragments. Cyclic fragments are counted once; execution reports
    # them as errors.
    private def complexity(selections : Array(Language::Selection), fragments : Array(Language::FragmentDefinition), visited = [] of String) : Int32
      selections.sum do |selection|
        case selection
        when Language::Field
          1 + complexity(selection.selections, fragments, visited)
        when Language::FragmentSpread
          fragment = fragments.find { |f| f.name == selection.name }
          if fragment.nil? || visited.includes?(selection.name)
            0
          else
            complexity(fragment.selections, fragments, visited + [selection.name])
          end
        when Language::InlineFragment
          complexity(selection.selections, fragments, visited)
        else
          0
        end
      end
    end

    def initialize(@query : QueryType, @mutation : MutationType? = nil)
      @document = @query._graphql_document
      if mutation = @mutation
        mutation._graphql_document.definitions.each do |definition|
          next unless definition.is_a?(Language::TypeDefinition)
          unless @document.definitions.find { |d| d.is_a?(Language::TypeDefinition) && d.name == definition.name }
            @document.definitions << definition
          end
        end
      end
    end

    def execute(query : String, variables : Hash(String, JSON::Any)? = nil, operation_name : String? = nil, context = Context.new) : String
      String.build do |io|
        execute(io, query, variables, operation_name, context)
      end
    end

    def execute(io : IO, query : String, variables : Hash(String, JSON::Any)? = nil, operation_name : String? = nil, context = Context.new) : Nil
      errors = [] of GraphQL::Error

      document = begin
        Language.parse(query)
      rescue ex : ParserError
        errors << Error.new(ex.message || "syntax error", [] of String | Int32)
        nil
      end

      operations = [] of Language::OperationDefinition

      context.query_type = @query._graphql_type
      context.mutation_type = @mutation.try &._graphql_type
      context.document = @document

      document.try &.visit(->(node : Language::ASTNode) {
        case node
        when Language::OperationDefinition
          operations << node
        when Language::FragmentDefinition
          context.fragments << node
        else
          nil
        end
      })

      operation = if document.nil?
                    nil
                  elsif operation_name.nil? && operations.size == 1
                    operations.first
                  else
                    if operation_name.nil?
                      errors << Error.new("sent more than one operation but did not set operation name", [] of String | Int32)
                      nil
                    elsif op = operations.find { |q| q.name == operation_name }
                      op
                    else
                      errors << Error.new("could not find operation with name #{operation_name}", [] of String | Int32)
                      nil
                    end
                  end

      if operation
        resolved = resolve_variables(operation, variables, errors)
        substitute = ->(node : Language::ASTNode) {
          substitute_variables(node, resolved, variables, errors) if node.is_a?(Language::Argument)
          nil
        }
        operation.visit(substitute)
        context.fragments.each &.visit(substitute)

        context.complexity = complexity(operation.selections, context.fragments)
        if (max = context.max_complexity) && context.complexity > max
          errors << Error.new("operation complexity #{context.complexity} exceeds the maximum of #{max}", [] of String | Int32)
        end

        operation = nil unless errors.empty?
      end

      JSON.build(io) do |json|
        json.object do
          if !operation.nil? && operation.operation_type == "query"
            json.field "data" do
              json.object do
                errors.concat @query._graphql_resolve(context, operation.selections, json)
              end
            end
          elsif !operation.nil? && operation.operation_type == "mutation"
            if mutation = @mutation
              json.field "data" do
                json.object do
                  errors.concat mutation._graphql_resolve(context, operation.selections, json, serial: true)
                end
              end
            else
              errors << Error.new("mutation operations are not supported", [] of String | Int32)
            end
          elsif !operation.nil?
            errors << Error.new("#{operation.operation_type} operations are not supported", [] of String | Int32)
          end
          unless errors.empty?
            json.field "errors" do
              errors.to_json(json)
            end
          end
        end
      end
    end
  end
end
