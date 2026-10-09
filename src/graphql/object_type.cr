require "./error"
require "./language"
require "./scalar_type"
require "./internal/convert_value"

module GraphQL::ObjectType
  # :nodoc:
  record JSONFragment, json : String, errors : Array(::GraphQL::Error)

  # :nodoc:
  alias PendingFragment = Channel(JSONFragment | ::Exception) | JSONFragment | ::Exception

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
              elsif (fa = field.arguments.find { |a| a.name == {{ arg.name.id.stringify.camelcase(lower: true) }} }) && !fa.value.nil?
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
            errors.concat introspection._graphql_resolve(context, field.selections, json)
          end
        {% end %}
        else
          raise ::GraphQL::TypeError.new("Field is not defined: #{field.name}")
        end
        errors.map &.with_path(path)

        {% end %}
      end

      {% end %}
      {% end %}
    end
  end

  # :nodoc:
  # Serializes `value` into `json`. Error paths are relative to the field:
  # the caller prepends the field's response key.
  private def _graphql_serialize(context, field : ::GraphQL::Language::Field, value, json : ::JSON::Builder) : Array(::GraphQL::Error)
    errors = [] of ::GraphQL::Error
    path = field._alias || field.name

    case value
    when ::GraphQL::ObjectType
      json.object do
        errors.concat value._graphql_resolve(context, field.selections, json)
      end
    when Array
      json.array do
        pending = value.map_with_index do |v, i|
          _graphql_fork(context) do
            _graphql_build_json_fragment(context, [i] of String | Int32) do |json|
              _graphql_serialize(context, field, v, json).map &.with_path(i)
            end
          end
        end

        pending.each do |item|
          fragment = _graphql_await(item)
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
  # Evaluates `@skip` and `@include` on a selection. A malformed directive
  # (the spec requires `if: Boolean!`) is reported under `path` and the
  # selection is skipped.
  private def _graphql_skip?(directives : Array(::GraphQL::Language::Directive), path : Array(String | Int32), errors : Array(::GraphQL::Error)) : Bool
    skip = false

    directives.each do |directive|
      next unless directive.name == "skip" || directive.name == "include"

      arg = directive.arguments.find { |a| a.name == "if" }
      if arg.nil?
        errors << ::GraphQL::Error.new("directive @#{directive.name} requires argument if", path)
        return true
      end

      value = arg.value
      unless value.is_a?(Bool)
        errors << ::GraphQL::Error.new("argument if of directive @#{directive.name} must be a Boolean", path)
        return true
      end

      skip ||= directive.name == "skip" ? value : !value
    end

    skip
  end

  # :nodoc:
  # Collects the fields selected by `selections` in query order, following
  # fragment spreads and inline fragments. Fields that share a response key
  # are merged into one entry, as the spec's CollectFields requires.
  private def _graphql_collect_fields(context, selections : Array(::GraphQL::Language::Selection), fields : Hash(String, ::GraphQL::Language::Field), errors : Array(::GraphQL::Error), visited_fragments = [] of String) : Nil
    selections.each do |selection|
      case selection
      when ::GraphQL::Language::Field
        path = selection._alias || selection.name
        next if _graphql_skip?(selection.directives, [path] of String | Int32, errors)
        if existing = fields[path]?
          next if selection.selections.empty?
          merged = existing.dup
          merged.selections = existing.selections + selection.selections
          fields[path] = merged
        else
          fields[path] = selection
        end
      when ::GraphQL::Language::FragmentSpread
        next if _graphql_skip?(selection.directives, [selection.name] of String | Int32, errors)
        if visited_fragments.includes?(selection.name)
          errors << ::GraphQL::Error.new("fragment #{selection.name} spreads itself", selection.name)
        elsif fragment = context.fragments.find { |f| f.name == selection.name }
          _graphql_collect_fields(context, fragment.selections, fields, errors, visited_fragments + [selection.name])
        else
          errors << ::GraphQL::Error.new("no fragment #{selection.name}", selection.name)
        end
      when ::GraphQL::Language::InlineFragment
        next if _graphql_skip?(selection.directives, [] of String | Int32, errors)
        _graphql_collect_fields(context, selection.selections, fields, errors, visited_fragments)
      else
        # this never happens, only required due to Selection being turned into ASTNode
        # https://crystal-lang.org/reference/1.3/syntax_and_semantics/virtual_and_abstract_types.html
        raise ::GraphQL::TypeError.new("invalid selection type")
      end
    end
  end

  # :nodoc:
  # With `serial` each field is fully resolved before the next one starts,
  # as the spec requires for the root fields of a mutation.
  protected def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection), json : JSON::Builder, serial : Bool = false) : Array(::GraphQL::Error)
    errors = [] of ::GraphQL::Error
    fields = Hash(String, ::GraphQL::Language::Field).new
    _graphql_collect_fields(context, selections, fields, errors)

    pending = Hash(String, PendingFragment).new
    fields.each do |path, field|
      pending[path] = _graphql_fork(context, serial) do
        _graphql_build_json_fragment(context, path) do |json|
          _graphql_resolve(context, field, json)
        end
      end
    end

    pending.each do |path, item|
      fragment = _graphql_await(item)
      errors.concat fragment.errors
      next if fragment.json.empty?

      json.field(path) { json.raw fragment.json }
    end

    errors
  end

  # :nodoc:
  # Builds a fragment in a new fiber if the context's concurrency budget
  # allows it, otherwise right here in the calling fiber. Either way the
  # result (or the exception it raised) is handed back to `_graphql_await`,
  # so ordering and error semantics are identical on both paths.
  private def _graphql_fork(context, serial : Bool = false, &block : -> JSONFragment) : PendingFragment
    if !serial && context._graphql_acquire?
      # Capacity 1 lets the fiber deliver its result and exit even when the
      # receiver gave up early because a sibling raised. With an unbuffered
      # channel such fibers would block on `send` forever.
      channel = Channel(JSONFragment | ::Exception).new(1)

      spawn do
        channel.send(block.call)
      rescue ex
        # unhandled exception, bubble up
        channel.send(ex)
      ensure
        context._graphql_release
      end

      channel
    else
      begin
        block.call
      rescue ex
        ex
      end
    end
  end

  # :nodoc:
  private def _graphql_await(pending : PendingFragment) : JSONFragment
    fragment = pending.is_a?(Channel) ? pending.receive : pending
    raise fragment if fragment.is_a?(::Exception)
    fragment
  end

  # :nodoc:
  private def _graphql_build_json_fragment(context, path : String | Array(Int32 | String), & : JSON::Builder -> Array(::GraphQL::Error)) : JSONFragment
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
