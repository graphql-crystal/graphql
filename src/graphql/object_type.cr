require "./error"
require "./language"
require "./scalar_type"
require "./internal/convert_value"

module GraphQL::ObjectType
  # :nodoc:
  record JSONFragment, json : String, errors : Array(::GraphQL::Error)

  macro included
    macro finished
      {% verbatim do %}
      {% verbatim do %}

      # :nodoc:
      def _graphql_type : String
        {{ @type.annotation(::GraphQL::Object)["name"] || @type.name.split("::").last }}
      end

      # :nodoc:
      def _graphql_resolve(context, field : ::GraphQL::Language::Field, json : JSON::Builder) : Array(::GraphQL::Error)
        {% begin %}
        errors = [] of ::GraphQL::Error
        path = field._alias || field.name

        case field.name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          errors.concat _graphql_serialize(context, field, self.{{var.name.id}}, json)
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
          errors.concat _graphql_serialize(context, field, value, json)
        {% end %}
        when "__typename"
          json.string _graphql_type
        {% if @type < ::GraphQL::QueryType %}
        when "__schema"
          json.object do
            introspection = ::GraphQL::Introspection::Schema.new(context.document.not_nil!, _graphql_type, context.mutation_type)
            introspection._graphql_resolve(context, field.selections, json).each do |error|
              errors << error.with_path(path)
            end
          end
        {% end %}
        else
          raise ::GraphQL::TypeError.new("field is not defined")
        end
        errors

        {% end %}
      end

      {% end %}
      {% end %}
    end
  end

  # :nodoc:
  private def _graphql_serialize(context, field : ::GraphQL::Language::Field, value, json : ::JSON::Builder) : Array(::GraphQL::Error)
    errors = [] of ::GraphQL::Error
    path = field._alias || field.name

    case value
    when ::GraphQL::ObjectType
      json.object do
        value._graphql_resolve(context, field.selections, json).each do |error|
          errors << error.with_path(path)
        end
      end
    when Array
      json.array do
        json_fragments = value.map_with_index do |v, i|
          channel = Channel(JSONFragment | ::Exception).new

          spawn do
            fragment = _graphql_build_json_fragment(context, [path, i]) do |json|
              _graphql_serialize(context, field, v, json).map do |error|
                error.with_path(i).with_path(path)
              end
            end

            channel.send(fragment)
          rescue ex
            # unhandled exception, bubble up
            channel.send(ex)
          end

          channel
        end

        json_fragments.each do |channel|
          fragment = channel.receive
          raise fragment if fragment.is_a?(::Exception)
          errors.concat fragment.errors

          next if fragment.json.empty?
          json.raw fragment.json
        end
      end
    when ::Enum
      json.string value
    when Bool, String, Int32, Float64, Nil, ::GraphQL::ScalarType
      value.to_json(json)
    else
      raise ::GraphQL::TypeError.new("no serialization found for field #{path} on #{_graphql_type}")
    end

    errors
  end

  # :nodoc:
  private def _graphql_skip?(selection : ::GraphQL::Language::Field | ::GraphQL::Language::FragmentSpread | ::GraphQL::Language::InlineFragment)
    if skip = selection.directives.find { |d| d.name == "skip" }
      if arg = skip.arguments.find { |a| a.name == "if" }
        return true if arg.value.as(Bool)
      end
    end

    if inc = selection.directives.find { |d| d.name == "include" }
      if arg = inc.arguments.find { |a| a.name == "if" }
        return true if !arg.value.as(Bool)
      end
    end

    false
  end

  # :nodoc:
  protected def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection), json : JSON::Builder) : Array(::GraphQL::Error)
    errors = [] of ::GraphQL::Error
    json_fragments = Hash(String, Channel(JSONFragment | ::Exception)).new

    selections.each do |selection|
      case selection
      when ::GraphQL::Language::Field
        next if _graphql_skip?(selection)
        path = selection._alias || selection.name
        json_fragments[path] = Channel(JSONFragment | ::Exception).new

        spawn do
          fragment = _graphql_build_json_fragment(context, path) do |json|
            _graphql_resolve(context, selection, json)
          end

          json_fragments[path].send fragment
        rescue ex
          # unhandled exception, bubble up
          json_fragments[path].send(ex)
        end
      when ::GraphQL::Language::FragmentSpread
        next if _graphql_skip?(selection)

        begin
          errors.concat _graphql_resolve(context, selection, json)
        rescue e
          if message = context.handle_exception(e)
            errors << ::GraphQL::Error.new(message, selection.name)
          end
        end
      when ::GraphQL::Language::InlineFragment
        next if _graphql_skip?(selection)

        errors.concat _graphql_resolve(context, selection.selections, json)
      else
        # this never happens, only required due to Selection being turned into ASTNode
        # https://crystal-lang.org/reference/1.3/syntax_and_semantics/virtual_and_abstract_types.html
        raise ::GraphQL::TypeError.new("invalid selection type")
      end
    end

    json_fragments.each do |path, channel|
      fragment = channel.receive
      raise fragment if fragment.is_a?(::Exception)

      errors.concat fragment.errors
      next if fragment.json.empty?

      json.field(path) { json.raw fragment.json }
    end

    errors
  end

  # :nodoc:
  private def _graphql_resolve(context, fragment : ::GraphQL::Language::FragmentSpread, json : JSON::Builder) : Array(::GraphQL::Error)
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
  private def _graphql_build_json_fragment(context, path : String | Array(Int32 | String), &block : JSON::Builder -> Array(::GraphQL::Error)) : JSONFragment
    errors = [] of ::GraphQL::Error

    json = String.build do |io|
      builder = JSON::Builder.new(io)
      builder.document do
        errors.concat yield builder
      end
    rescue e
      if message = context.handle_exception(e)
        errors << ::GraphQL::Error.new(message, path)
      end
    end

    JSONFragment.new(json, errors)
  end
end

module GraphQL
  abstract class BaseObject
    macro inherited
      include GraphQL::ObjectType
    end
  end
end
