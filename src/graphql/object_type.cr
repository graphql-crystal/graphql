require "./language"
require "./scalar_type"
require "./internal/convert_value"

module GraphQL::ObjectType
  alias ObjectHashMember = Union(
    String,
    Int32,
    Float64,
    Bool,
    Nil,
    Array(ObjectHashMember),
    ObjectHash,
    GraphQL::ScalarType,
  )
  alias ObjectHash = Hash(String, ObjectHashMember)

  record ResolveResult(V), data : V, errors : Array(GraphQL::Error) = [] of GraphQL::Error

  macro included
    macro finished
      {% verbatim do %}
      {% verbatim do %}

      # :nodoc:
      def _graphql_type : String
        {{ @type.annotation(::GraphQL::Object)["name"] || @type.name.split("::").last }}
      end

      # :nodoc:
      def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection)) : ResolveResult(ObjectHash)
        errors = [] of ::GraphQL::Error
        data = ObjectHash.new

        field_results = Hash(String, Channel(ResolveResult(ObjectHashMember) | ::Exception)).new

        selections.each do |selection|
          case selection
          when ::GraphQL::Language::Field, ::GraphQL::Language::FragmentSpread, ::GraphQL::Language::InlineFragment
            if skip = selection.directives.find { |d| d.name == "skip" }
              if arg = skip.arguments.find { |a| a.name == "if" }
                next if arg.value.as(Bool)
              end
            end
            if inc = selection.directives.find { |d| d.name == "include" }
              if arg = inc.arguments.find { |a| a.name == "if" }
                next if !arg.value.as(Bool)
              end
            end

            case selection
            when ::GraphQL::Language::Field
              path = selection._alias || selection.name
              field_results[path] = Channel(ResolveResult(ObjectHashMember) | ::Exception).new

              spawn do
                field_result = _graphql_resolve(context, selection)
                field_results[path].send(field_result)
              rescue ex
                field_results[path].send(ex)
              end
            when ::GraphQL::Language::FragmentSpread
              begin
                fragment_result = _graphql_resolve(context, selection)
                errors.concat fragment_result.errors
                data.merge! fragment_result.data
              rescue e
                if message = context.handle_exception(e)
                  errors << ::GraphQL::Error.new(message, selection.name)
                end
              end
            when ::GraphQL::Language::InlineFragment
              fragment_result = _graphql_resolve(context, selection.selections)
              errors.concat fragment_result.errors
              data.merge! fragment_result.data
            end
          else
            # this never happens, only required due to Selection being turned into ASTNode
            # https://crystal-lang.org/reference/1.3/syntax_and_semantics/virtual_and_abstract_types.html
            raise ::GraphQL::TypeError.new("invalid selection type")
          end
        end

        field_results.each do |path, channel|
          field_result = channel.receive

          case field_result
          when ResolveResult
            data[path] = field_result.data
            errors.concat field_result.errors
          when ::Exception
            if message = context.handle_exception(field_result)
              errors << ::GraphQL::Error.new(message, path)
            end
          end
        end

        ResolveResult.new(data, errors)
      end


      # :nodoc:
      def _graphql_resolve(context, fragment : ::GraphQL::Language::FragmentSpread) : ResolveResult(ObjectHash)
        errors = [] of ::GraphQL::Error
        data = ObjectHash.new

        f = context.fragments.find{ |f| f.name == fragment.name}
        if f.nil?
          errors << ::GraphQL::Error.new("no fragment #{fragment.name}", fragment.name)
        else
          fragment_result = _graphql_resolve(context, f.selections)
          errors.concat fragment_result.errors
          data.merge! fragment_result.data
        end

        ResolveResult.new(data, errors)
      end

      # :nodoc:
      def _graphql_resolve(context, field : ::GraphQL::Language::Field) : ResolveResult(ObjectHashMember)
        {% begin %}
        case field.name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          return _graphql_resolve(context, field, self.{{var.name.id}})
        {% end %}
        {% methods = @type.methods.select(&.annotation(::GraphQL::Field)) %}
        {% for ancestor in @type.ancestors %}
          {% for method in ancestor.methods.select(&.annotation(::GraphQL::Field)) %}
            {% methods << method %}
          {% end %}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          value = self.{{method.name.id}}(
            {% for arg in method.args %}
            {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
            {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
            {{ arg.name }}: begin
              if context.is_a? {{arg.restriction.id}}
                context
              elsif fa = field.arguments.find {|a| a.name == {{ arg.name.id.stringify.camelcase(lower: true) }}}
                GraphQL::Internal.convert_value {{ type }}, fa.value, {{ arg.name.id.camelcase(lower: true) }}
              else
                {% if !arg.default_value.is_a?(Nop) %}
                  {{ arg.default_value }}.as({{arg.restriction.id}})
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise ::GraphQL::TypeError.new("missing required argument {{ arg.name.id.camelcase(lower: true) }}")
                {% end %}
              end
            end,
            {% end %}
          )
          return _graphql_resolve(context, field, value)
        {% end %}
        else
          raise ::GraphQL::TypeError.new("field is not defined")
        end
        {% end %}
      end

      def _graphql_resolve(context, field : ::GraphQL::Language::Field, value) : ResolveResult(ObjectHashMember)
        path = field._alias || field.name
        errors = [] of ::GraphQL::Error

        case value
        when ::GraphQL::ObjectType
          object_result = value._graphql_resolve(context, field.selections)
          object_result.errors.each do |error|
            errors << error.with_path(path)
          end

          return ResolveResult(ObjectHashMember).new(object_result.data, errors)
        when Array
          results = value.map_with_index do |v, i|
            Channel(ResolveResult(ObjectHashMember)).new.tap do |channel|
              spawn { channel.send _graphql_resolve(context, field, v) }
            end
          end

          array_data = [] of ObjectHashMember

          results.each_with_index do |channel, i|
            member_result = channel.receive
            array_data << member_result.data
            member_result.errors.each do |error|
              errors << error.with_path(i).with_path(path)
            end
          end

          ResolveResult(ObjectHashMember).new(array_data, errors)
        when ::Enum
          ResolveResult(ObjectHashMember).new(value.to_s)
        when Bool, String, Int32, Float64, Nil, ::GraphQL::ScalarType
          ResolveResult(ObjectHashMember).new(value)
        else
          raise ::GraphQL::TypeError.new("no serialization found for field #{path} on #{_graphql_type}")
        end
      end

      {% end %}
      {% end %}
    end
  end
end

module GraphQL
  abstract class BaseObject
    macro inherited
      include GraphQL::ObjectType
    end
  end
end
