require "./language"
require "./scalar_type"

module GraphQL::ObjectType
  macro convert_value(t, value, name)
    {% type = t.resolve %}
    case %value = {{value}}
    when {{type}}
      %value
    {% if type == Float64 %}
    when Int32
      %value.to_f64.as({{type}})
    {% elsif type.resolve.annotation(::GraphQL::Enum) %}
    when ::GraphQL::Language::AEnum
      {{type}}.parse(%value.to_value)
    when String
      {{type}}.parse(%value)
    {% elsif type.annotation(::GraphQL::InputObject) %}
    when ::GraphQL::Language::InputObject
      {{type}}._graphql_new(%value.as(::GraphQL::Language::InputObject))
    {% elsif type < ::GraphQL::ScalarType %}
    when String, Int32, Float64
      {{type}}.from_json(%value.to_json)
    {% elsif type < Array %}
    when Array
      {% inner_type = type.type_vars.find { |t| t != Nil } %}
      %value.map do |%v|
        ::GraphQL::ObjectType.convert_value {{ inner_type }}, %v, name
      end
    {% end %}
    else
      raise ::GraphQL::TypeError.new("bad type for argument {{ name }}")
    end.as({{type}})
  end

  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def _graphql_type : String
        {{ @type.annotation(::GraphQL::Object)["name"] || @type.name.split("::").last }}
      end

      # :nodoc:
      def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection), json : JSON::Builder) : Array(::GraphQL::Error)
        errors = [] of ::GraphQL::Error
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
            when ::GraphQL::Language::Field, ::GraphQL::Language::FragmentSpread
              begin
                errors.concat _graphql_resolve(context, selection, json)
              rescue e
                if message = context.handle_exception(e)
                  errors << ::GraphQL::Error.new(
                    message,
                    selection.is_a?(::GraphQL::Language::Field) ? selection._alias || selection.name : selection.name
                  )
                end
              end
            when ::GraphQL::Language::InlineFragment
              errors.concat _graphql_resolve(context, selection.selections, json)
            end
          else
            # this never happens, only required due to Selection being turned into ASTNode
            # https://crystal-lang.org/reference/1.3/syntax_and_semantics/virtual_and_abstract_types.html
            raise ::GraphQL::TypeError.new("invalid selection type")
          end
        end
        errors
      end


      # :nodoc:
      def _graphql_resolve(context, fragment : ::GraphQL::Language::FragmentSpread, json : JSON::Builder) : Array(::GraphQL::Error)
        errors = [] of ::GraphQL::Error
        f = context.fragments.find{ |f| f.name == fragment.name}
        if f.nil?
          errors << ::GraphQL::Error.new("no fragment #{fragment.name}", fragment.name)
        else
          errors.concat _graphql_resolve(context, f.selections, json)
        end
        errors
      end

      # :nodoc:
      def _graphql_resolve(context, field : ::GraphQL::Language::Field, json : JSON::Builder) : Array(::GraphQL::Error)
        errors = [] of ::GraphQL::Error
        path = field._alias || field.name

        case field.name
        {% methods = @type.methods.select(&.annotation(::GraphQL::Field)) %}
        {% for ancestor in @type.ancestors %}
          {% for method in ancestor.methods.select(&.annotation(::GraphQL::Field)) %}
            {% methods << method %}
          {% end %}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          case result = self.{{method.name.id}}(
            {% for arg in method.args %}
            {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
            {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
            {{ arg.name }}: begin
              if context.is_a? {{arg.restriction.id}}
                context
              elsif fa = field.arguments.find {|a| a.name == {{ arg.name.id.stringify.camelcase(lower: true) }}}
                convert_value {{ type }}, fa.value, {{ arg.name.id.camelcase(lower: true) }}
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
          when ::GraphQL::ObjectType
            json.field path do
              json.object do
                result._graphql_resolve(context, field.selections, json).each do |error|
                  errors << error.with_path(path)
                end
              end
            end
          when Array
            json.field path do
              json.array do
                result.each_with_index do |v, i|
                  case v
                  when ::GraphQL::ObjectType
                    json.object do
                      v._graphql_resolve(context, field.selections, json).each do |error|
                        errors << error.with_path(i).with_path(path)
                      end
                    end
                  when ::Enum
                    json.scalar(v.to_s)
                  else
                    v.to_json(json)
                  end
                end
              end
            end
          when ::Enum
            json.field path, result.to_s
          when Bool, String, Int32, Float64, Nil, ::GraphQL::ScalarType
            json.field path, result
          else
            raise ::GraphQL::TypeError.new("no serialization found for field #{path} on #{_graphql_type}")
          end
        {% end %}
        when "__typename"
          json.field path, _graphql_type
        {% if @type < ::GraphQL::QueryType %}
        when "__schema"
          json.field path do
            json.object do
              introspection = ::GraphQL::Introspection::Schema.new(context.document.not_nil!, _graphql_type, context.mutation_type)
              introspection._graphql_resolve(context, field.selections, json).each do |error|
                errors << error.with_path(path)
              end
            end
          end
        {% end %}
        else
          raise ::GraphQL::TypeError.new("field is not defined")
        end
        errors
      end
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
