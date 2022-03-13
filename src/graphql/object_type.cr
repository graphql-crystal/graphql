require "./language"

module GraphQL::ObjectType
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

          if selection.is_a?(::GraphQL::Language::Field) || selection.is_a?(::GraphQL::Language::FragmentSpread)
            if skip = selection.directives.find {|d| d.name == "skip"}
              if arg = skip.arguments.find {|a| a.name == "if"}
                next if arg.value.as(Bool)
              end
            end
            if inc = selection.directives.find {|d| d.name == "include"}
              if arg = inc.arguments.find {|a| a.name == "if"}
                next if !arg.value.as(Bool)
              end
            end
          # TODO we should be able to combine this with the if above??
          elsif selection.is_a?(::GraphQL::Language::InlineFragment)
            if skip = selection.directives.find {|d| d.name == "skip"}
              if arg = skip.arguments.find {|a| a.name == "if"}
                next if arg.value.as(Bool)
              end
            end
            if inc = selection.directives.find {|d| d.name == "include"}
              if arg = inc.arguments.find {|a| a.name == "if"}
                next if !arg.value.as(Bool)
              end
            end
          else
            raise "failed to resolve selection #{selection}"
          end

          case selection
          when ::GraphQL::Language::Field, ::GraphQL::Language::FragmentSpread
            begin
              errors.concat _graphql_resolve(context, selection, json)
            rescue e
              if !e.message.nil?
                errors << ::GraphQL::Error.new(
                  e.message.not_nil!,
                  selection.is_a?(::GraphQL::Language::Field) ? selection._alias || selection.name : selection.name
                )
              end
            end
          when ::GraphQL::Language::InlineFragment
            errors.concat _graphql_resolve(context, selection.selections, json)
          when ::GraphQL::Language::ASTNode
            raise "GraphQL: selection is ASTNode - this should never happen"
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
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
            {% methods << var %}
          {% end %}
        {% for ancestor in @type.ancestors %}
          {% for method in ancestor.methods.select(&.annotation(::GraphQL::Field)) %}
            {% methods << method %}
          {% end %}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          case value = self.{{method.name.id}}(
            {% for arg in method.args %}
            {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
            {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}

            {{ arg.name }}: begin
              if context.is_a? {{arg.restriction.id}}
                context
              elsif arg = field.arguments.find {|a| a.name == {{ arg.name.id.stringify.camelcase(lower: true) }}}
                begin
                  case arg_value = arg.value
                  when {{type.id}}
                    arg_value
                  {% if type == Float64 %}
                  when Int32
                    arg_value.to_f64.as({{type.id}})
                  {% elsif type.annotation(::GraphQL::Enum) %}
                  when ::GraphQL::Language::AEnum
                    {{type.id}}.parse(arg_value.to_value)
                  when String
                    {{type.id}}.parse(arg_value)
                  {% elsif type.annotation(::GraphQL::InputObject) %}
                  when ::GraphQL::Language::InputObject
                    {{type.id}}._graphql_new(arg_value)
                  {% elsif type < ::GraphQL::ScalarType %}
                  when String, Int32, Float64
                    {{type.id}}.from_json(arg_value.to_json)
                  {% elsif type < Array %}
                  {% inner_type = type.type_vars.find { |t| t != Nil }.resolve %}
                  when Array
                    arg_value.map do |value|
                      case value
                      when {{inner_type.id}}
                        value
                      {% if inner_type == Float64 %}
                      when Int32
                        value.to_f64.as({{inner_type.id}})
                      {% elsif inner_type.annotation(::GraphQL::Enum) %}
                      when ::GraphQL::Language::AEnum
                        {{inner_type.id}}.parse(value.to_value)
                      when String
                        {{inner_type.id}}.parse(value)
                      {% elsif inner_type.annotation(::GraphQL::InputObject) %}
                      when ::GraphQL::Language::InputObject
                        {{inner_type.id}}._graphql_new(value)
                      {% elsif type < ::GraphQL::ScalarType %}
                      when String, Int32, Float64
                        {{type.id}}.from_json(arg_value.to_json)
                      {% elsif inner_type < Array %}
                        {% raise "GraphQL: #{@type.name}##{method.name} nested arrays are not supported" %}
                      {% end %}
                      else
                        return [GraphQL::Error.new("wrong type for argument {{ arg.name.id.camelcase(lower: true) }}", path)]
                      end
                    end
                  {% end %}
                  else
                    return [GraphQL::Error.new("#{arg_value} is wrong type for argument {{ arg.name.id.camelcase(lower: true) }}", path)]
                  end
                rescue TypeCastError
                  return [GraphQL::Error.new("wrong type for argument {{ arg.name.id.camelcase(lower: true) }}", path)]
                end
              else
                {% if !arg.default_value.is_a?(Nop) %}
                  {{ arg.default_value }}.as({{arg.restriction.id}})
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  return [GraphQL::Error.new("missing required argument {{ arg.name.id.camelcase(lower: true) }}", path)]
                {% end %}
              end
            end,
            {% end %}
          )
          when ::GraphQL::ObjectType
            json.field path do
              json.object do
                value._graphql_resolve(context, field.selections, json).each do |error|
                  errors << error.with_path(path)
                end
              end
            end
          when Array
            json.field path do
              json.array do
                value.each_with_index do |v, i|
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
            json.field path, value.to_s
          when Bool, String, Int32, Int64, Float32, Float64, Nil, ::GraphQL::ScalarType
            json.field path, value
          else
            raise "no serialization found for field #{path} on #{_graphql_type}"
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
          errors << ::GraphQL::Error.new("field is not defined", path)
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
