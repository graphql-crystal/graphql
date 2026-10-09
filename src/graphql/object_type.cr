require "./error"
require "./language"
require "./scalar_type"
require "./internal/convert_value"

module GraphQL::ObjectType
  # :nodoc:
  record JSONFragment, json : String, errors : Array(::GraphQL::Error)

  # :nodoc:
  # Returned where nothing went wrong, so leaf fields allocate no error
  # array. Never mutated: callers only read it or concat it elsewhere.
  NO_ERRORS = [] of ::GraphQL::Error

  # :nodoc:
  alias PendingFragment = Channel(JSONFragment | ::Exception) | JSONFragment | ::Exception

  # :nodoc:
  # Raised when a non-null field or list element failed to resolve. It
  # carries every error collected so far in the enclosing fragment, and the
  # enclosing fragment's builder turns it into a failed fragment, so the
  # failure travels up to the nearest nullable ancestor as the spec requires.
  class NullPropagation < ::Exception
    getter errors : Array(::GraphQL::Error)

    def initialize(@errors)
      super("non-null field resolved to null")
    end
  end

  macro included
    macro finished
      {% verbatim do %}
      {% verbatim do %}

      # :nodoc:
      def _graphql_type : String
        {{ (@type.annotation(::GraphQL::Object) && @type.annotation(::GraphQL::Object)["name"]) || @type.name.split("::").last }}
      end

      # :nodoc:
      # Names of the interfaces and unions this type belongs to, so fragments
      # conditioned on them apply to this object.
      def _graphql_abstract_types : Array(String)
        {% begin %}
        {% abstract_types = @type.ancestors.select { |a| a.annotation(::GraphQL::Interface) || a.annotation(::GraphQL::Union) } %}
        {% names = abstract_types.map { |a| ((a.annotation(::GraphQL::Interface) || a.annotation(::GraphQL::Union))["name"]) || a.name.split("::").last } %}
        {% if names.empty? %}
        [] of String
        {% else %}
        {{ names }}
        {% end %}
        {% end %}
      end

      # :nodoc:
      # Whether the named field may be null in the response. Unknown fields
      # count as nullable, so their "not defined" error does not take the
      # whole parent down with it.
      def _graphql_field_nullable?(name : String) : Bool
        {% begin %}
        {%
          methods = @type.methods.select(&.annotation(::GraphQL::Field))
          @type.ancestors.each do |ancestor|
            ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
          end
          # an override and the method it overrides describe one field
          seen = [] of String
          methods = methods.select do |m|
            n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
            seen.includes?(n) ? false : (seen << n; true)
          end
        %}
        case name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          {{ var.type.nilable? }}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          {% if method.return_type.is_a?(Nop) %}
          true
          {% else %}
          {% rt = method.return_type.resolve %}
          {% rt = rt.type_vars.first if rt < Channel %}
          {{ rt.nilable? }}
          {% end %}
        {% end %}
        when "__typename", "__schema"
          false
        else
          true
        end
        {% end %}
      end

      # :nodoc:
      # Whether the named field's value is a scalar, enum, or list of those,
      # which the sequential path writes straight into the parent builder.
      # The library's own scalars qualify; custom scalars are excluded
      # because their `to_json` is user code.
      def _graphql_leaf_field?(name : String) : Bool
        {% begin %}
        {%
          methods = @type.methods.select(&.annotation(::GraphQL::Field))
          @type.ancestors.each do |ancestor|
            ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
          end
          # an override and the method it overrides describe one field
          seen = [] of String
          methods = methods.select do |m|
            n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
            seen.includes?(n) ? false : (seen << n; true)
          end
        %}
        case name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          {% leaf = var.type %}
          {% for _ in 0..7 %}
            {% leaf = leaf.union_types.find { |u| u != Nil } %}
            {% if leaf < Array || leaf < Channel %}
              {% leaf = leaf.type_vars.first %}
            {% end %}
          {% end %}
          {% leaf = parse_type(leaf.name.stringify).resolve %}
          {{ leaf == String || leaf == Int32 || leaf == Float64 || leaf == Bool || leaf < ::Enum || (leaf < ::GraphQL::ScalarType && leaf.name.stringify.starts_with?("GraphQL::Scalars::")) }}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          {% if method.return_type.is_a?(Nop) %}
          false
          {% else %}
          {% leaf = method.return_type.resolve %}
          {% for _ in 0..7 %}
            {% leaf = leaf.union_types.find { |u| u != Nil } %}
            {% if leaf < Array || leaf < Channel %}
              {% leaf = leaf.type_vars.first %}
            {% end %}
          {% end %}
          {% leaf = parse_type(leaf.name.stringify).resolve %}
          {{ leaf == String || leaf == Int32 || leaf == Float64 || leaf == Bool || leaf < ::Enum || (leaf < ::GraphQL::ScalarType && leaf.name.stringify.starts_with?("GraphQL::Scalars::")) }}
          {% end %}
        {% end %}
        when "__typename"
          true
        else
          false
        end
        {% end %}
      end

      # :nodoc:
      # Sequential path for a leaf field: resolves the value, then writes it
      # straight into `json` under `path`. Each branch keeps the field's
      # static type, which the serializer needs for element nullability.
      # Returns whether the field failed.
      def _graphql_resolve_leaf(context, field : ::GraphQL::Language::Field, path : String, json : JSON::Builder, errors : Array(::GraphQL::Error)) : Bool
        {% begin %}
        {%
          methods = @type.methods.select(&.annotation(::GraphQL::Field))
          @type.ancestors.each do |ancestor|
            ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
          end
          # an override and the method it overrides describe one field
          seen = [] of String
          methods = methods.select do |m|
            n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
            seen.includes?(n) ? false : (seen << n; true)
          end
        %}
        case field.name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          {% leaf = var.type %}
          {% for _ in 0..7 %}
            {% leaf = leaf.union_types.find { |u| u != Nil } %}
            {% if leaf < Array %}
              {% leaf = leaf.type_vars.first %}
            {% end %}
          {% end %}
          {% leaf = parse_type(leaf.name.stringify).resolve %} # a virtual type (abstract class element) carries no annotations
          {% if leaf.annotation(::GraphQL::Object) || leaf.annotation(::GraphQL::Interface) || leaf.annotation(::GraphQL::Union) %}
          raise ::GraphQL::TypeError.new("field #{field.name} must have a selection of subfields") if field.selections.empty?
          {% else %}
          raise ::GraphQL::TypeError.new("field #{field.name} must not have a selection since its type has no subfields") unless field.selections.empty?
          {% end %}
          value = begin
            raise ::GraphQL::TypeError.new("unknown argument #{field.arguments.first.name} on field #{field.name}") unless field.arguments.empty?
            self.{{ var.name.id }}
          rescue e
            return _graphql_leaf_failed(context, e, field, path, json, errors)
          end
          _graphql_write_leaf(context, field, path, value, json, errors)
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          value = begin
            _graphql_call_{{ method.name.id }}(context, field)
          rescue e
            return _graphql_leaf_failed(context, e, field, path, json, errors)
          end
          _graphql_write_leaf(context, field, path, value, json, errors)
        {% end %}
        when "__typename"
          unless field.selections.empty?
            return _graphql_leaf_failed(context, ::GraphQL::TypeError.new("field __typename must not have a selection since its type has no subfields"), field, path, json, errors)
          end
          json.field(path) { json.string _graphql_type }
          false
        else
          _graphql_leaf_failed(context, ::GraphQL::TypeError.new("Field is not defined: #{field.name}"), field, path, json, errors)
        end
        {% end %}
      end

      {% begin %}
      {%
        methods = @type.methods.select(&.annotation(::GraphQL::Field))
        @type.ancestors.each do |ancestor|
          ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
        end
        # an override and the method it overrides describe one field
        seen = [] of String
        methods = methods.select do |m|
          n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
          seen.includes?(n) ? false : (seen << n; true)
        end
      %}
      {% for method in methods %}
      {% ann_args = method.annotation(::GraphQL::Field)["arguments"] %}
      {% arg_names = method.args.map { |a| (ann_args && ann_args[a.name.id] && ann_args[a.name.id]["name"]) || a.name.id.stringify.camelcase(lower: true) } %}
      # :nodoc:
      # Validates `field` against the declaration of `{{ method.name }}` and
      # calls it with the coerced arguments.
      private def _graphql_call_{{ method.name.id }}(context, field : ::GraphQL::Language::Field)
        {% unless method.return_type.is_a?(Nop) %}
        {% leaf = method.return_type.resolve %}
        {% for _ in 0..7 %}
          {% leaf = leaf.union_types.find { |u| u != Nil } %}
          {% if leaf < Array || leaf < Channel %}
            {% leaf = leaf.type_vars.first %}
          {% end %}
        {% end %}
        {% leaf = parse_type(leaf.name.stringify).resolve %} # a virtual type (abstract class element) carries no annotations
        {% if leaf.annotation(::GraphQL::Object) || leaf.annotation(::GraphQL::Interface) || leaf.annotation(::GraphQL::Union) %}
        raise ::GraphQL::TypeError.new("field #{field.name} must have a selection of subfields") if field.selections.empty?
        {% else %}
        raise ::GraphQL::TypeError.new("field #{field.name} must not have a selection since its type has no subfields") unless field.selections.empty?
        {% end %}
        {% end %}
        field.arguments.each do |fa|
          {% if arg_names.empty? %}
          raise ::GraphQL::TypeError.new("unknown argument #{fa.name} on field #{field.name}")
          {% else %}
          raise ::GraphQL::TypeError.new("unknown argument #{fa.name} on field #{field.name}") unless {{ arg_names }}.includes?(fa.name)
          {% end %}
        end
        self.{{ method.name.id }}(
          {% for arg, i in method.args %}
          {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
          {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
          {% gql_name = arg_names[i] %}
          {{ arg.name }}: begin
            if context.is_a? {{ arg.restriction.id }}
              context
            elsif (fa = field.arguments.find { |a| a.name == {{ gql_name }} }) && !fa.value.nil?
              GraphQL::Internal.convert_value {{ type }}, fa.value, {{ gql_name.id }}
            else
              {% if !arg.default_value.is_a?(Nop) %}
                {{ arg.default_value }}.as({{ arg.restriction.id }})
              {% elsif arg.restriction.resolve.nilable? %}
                nil
              {% else %}
                raise ::GraphQL::TypeError.new("missing required argument {{ gql_name.id }}")
              {% end %}
            end
          end,
          {% end %}
        )
      end
      {% end %}
      {% end %}

      # :nodoc:
      def _graphql_resolve(context, field : ::GraphQL::Language::Field, json : JSON::Builder) : Array(::GraphQL::Error)
        {% begin %}
        {%
          methods = @type.methods.select(&.annotation(::GraphQL::Field))
          @type.ancestors.each do |ancestor|
            ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
          end
          # an override and the method it overrides describe one field
          seen = [] of String
          methods = methods.select do |m|
            n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
            seen.includes?(n) ? false : (seen << n; true)
          end
        %}
        errors = NO_ERRORS
        path = field._alias || field.name

        case field.name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          {% leaf = var.type %}
          {% for _ in 0..7 %}
            {% leaf = leaf.union_types.find { |u| u != Nil } %}
            {% if leaf < Array %}
              {% leaf = leaf.type_vars.first %}
            {% end %}
          {% end %}
          {% leaf = parse_type(leaf.name.stringify).resolve %} # a virtual type (abstract class element) carries no annotations
          {% if leaf.annotation(::GraphQL::Object) || leaf.annotation(::GraphQL::Interface) || leaf.annotation(::GraphQL::Union) %}
          raise ::GraphQL::TypeError.new("field #{field.name} must have a selection of subfields") if field.selections.empty?
          {% else %}
          raise ::GraphQL::TypeError.new("field #{field.name} must not have a selection since its type has no subfields") unless field.selections.empty?
          {% end %}
          raise ::GraphQL::TypeError.new("unknown argument #{field.arguments.first.name} on field #{field.name}") unless field.arguments.empty?
          errors = _graphql_serialize(context, field, self.{{ var.name.id }}, json)
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          errors = _graphql_serialize(context, field, _graphql_call_{{ method.name.id }}(context, field), json)
        {% end %}
        when "__typename"
          raise ::GraphQL::TypeError.new("field __typename must not have a selection since its type has no subfields") unless field.selections.empty?
          json.string _graphql_type
        {% if @type < ::GraphQL::QueryType %}
        when "__schema"
          raise ::GraphQL::TypeError.new("field __schema must have a selection of subfields") if field.selections.empty?
          json.object do
            introspection = ::GraphQL::Introspection::Schema.new(context.document.not_nil!, _graphql_type, context.mutation_type, context.subscription_type)
            errors = introspection._graphql_resolve(context, field.selections, json)
          end
        when "__type"
          raise ::GraphQL::TypeError.new("field __type must have a selection of subfields") if field.selections.empty?
          type_name = field.arguments.find { |a| a.name == "name" }.try(&.value)
          raise ::GraphQL::TypeError.new("missing required argument name") unless type_name.is_a?(String)
          document = context.document.not_nil!
          if definition = document.definitions.find { |d| d.is_a?(::GraphQL::Language::TypeDefinition) && d.name == type_name }
            json.object do
              errors = ::GraphQL::Introspection::Type.new(document, definition.as(::GraphQL::Language::TypeDefinition))._graphql_resolve(context, field.selections, json)
            end
          else
            json.null
          end
        {% end %}
        else
          raise ::GraphQL::TypeError.new("Field is not defined: #{field.name}")
        end
        errors.each &.with_path(path)
        errors
        {% end %}
      end

      {% if @type < ::GraphQL::SubscriptionType %}
      # :nodoc:
      # Starts the event stream of one root subscription field.
      def _graphql_subscribe_field(context, field : ::GraphQL::Language::Field) : ::GraphQL::Subscription
        {% begin %}
        {%
          methods = @type.methods.select(&.annotation(::GraphQL::Field))
          @type.ancestors.each do |ancestor|
            ancestor.methods.select(&.annotation(::GraphQL::Field)).each { |m| methods << m }
          end
          # an override and the method it overrides describe one field
          seen = [] of String
          methods = methods.select do |m|
            n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
            seen.includes?(n) ? false : (seen << n; true)
          end
        %}
        case field.name
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          _graphql_forward(context, field, _graphql_call_{{ method.name.id }}(context, field))
        {% end %}
        else
          raise ::GraphQL::TypeError.new("Field is not defined: #{field.name}")
        end
        {% end %}
      end
      {% end %}

      {% end %}
      {% end %}
    end
  end

  # :nodoc:
  # Serializes `value` into `json`. Error paths are relative to the field:
  # the caller prepends the field's response key.
  private def _graphql_serialize(context, field : ::GraphQL::Language::Field, value, json : ::JSON::Builder) : Array(::GraphQL::Error)
    path = field._alias || field.name

    case value
    when ::GraphQL::ObjectType
      errors = NO_ERRORS
      json.object do
        errors = value._graphql_resolve(context, field.selections, json)
      end
      return errors
    when Array
      if context.max_concurrency == 0 && _graphql_leaf_elements?(value) && _graphql_finite?(value)
        json.array do
          value.each { |v| _graphql_serialize(context, field, v, json) }
        end
        return NO_ERRORS
      end

      errors = [] of ::GraphQL::Error
      json.array do
        # `first` is never called; `typeof` only inspects the element type.
        element_nullable = typeof(value.first).nilable?
        propagate = false

        if context.max_concurrency == 0
          # one buffer per element, nothing else
          value.each_with_index do |v, i|
            fragment = _graphql_build_json_fragment(context, i, field) do |element_json|
              element_errors = _graphql_serialize(context, field, v, element_json)
              element_errors.each &.with_path(i)
              element_errors
            end
            errors.concat fragment.errors

            if fragment.json.empty?
              propagate = true unless element_nullable
              json.null
            else
              json.raw fragment.json
            end
          end
        else
          pending = value.map_with_index do |v, i|
            _graphql_fork(context) do
              _graphql_build_json_fragment(context, i, field) do |element_json|
                element_errors = _graphql_serialize(context, field, v, element_json)
                element_errors.each &.with_path(i)
                element_errors
              end
            end
          end

          pending.each do |item|
            fragment = _graphql_await(item)
            errors.concat fragment.errors

            if fragment.json.empty?
              propagate = true unless element_nullable
              json.null
            else
              json.raw fragment.json
            end
          end
        end

        raise NullPropagation.new(errors) if propagate
      end
      return errors
    when ::Enum
      json.string value
    when Float64
      raise ::GraphQL::TypeError.new("Float cannot represent non-finite value") unless value.finite?
      value.to_json(json)
    when ::GraphQL::Scalars::Float
      raise ::GraphQL::TypeError.new("Float cannot represent non-finite value") unless value.value.finite?
      value.to_json(json)
    when Bool, String, Int32, Nil, ::GraphQL::ScalarType
      value.to_json(json)
    when Channel
      raise ::GraphQL::TypeError.new("field #{path} on #{_graphql_type} returns a Channel; only subscription root fields may")
    else
      raise ::GraphQL::TypeError.new("no serialization found for field #{path} on #{_graphql_type}")
    end

    NO_ERRORS
  end

  # :nodoc:
  # Evaluates `@skip` and `@include` on a selection. A malformed directive
  # (the spec requires `if: Boolean!`) is reported under `path` and the
  # selection is skipped.
  private def _graphql_skip?(selection : ::GraphQL::Language::ASTNode, directives : Array(::GraphQL::Language::Directive), path : Array(String | Int32)?, errors : Array(::GraphQL::Error)) : Bool
    skip = false

    directives.each do |directive|
      unless directive.name == "skip" || directive.name == "include"
        errors << ::GraphQL::Error.new("unknown directive @#{directive.name}", path, selection)
        return true
      end

      arg = directive.arguments.find { |a| a.name == "if" }
      if arg.nil?
        errors << ::GraphQL::Error.new("directive @#{directive.name} requires argument if", path, selection)
        return true
      end

      value = arg.value
      unless value.is_a?(Bool)
        errors << ::GraphQL::Error.new("argument if of directive @#{directive.name} must be a Boolean", path, selection)
        return true
      end

      skip ||= directive.name == "skip" ? value : !value
    end

    skip
  end

  # :nodoc:
  # A fragment applies to objects of the type it was declared on, and to
  # objects implementing that interface or belonging to that union. An
  # absent condition (`... { }`) always applies.
  private def _graphql_type_condition_matches?(type : ::GraphQL::Language::Type?) : Bool
    case type
    when Nil                           then true
    when ::GraphQL::Language::TypeName then type.name == _graphql_type || _graphql_abstract_types.includes?(type.name)
    else                                    false
    end
  end

  # :nodoc:
  # Collects the fields selected by `selections` in query order, following
  # fragment spreads and inline fragments. Fields that share a response key
  # are merged into one entry, as the spec's CollectFields requires.
  private def _graphql_collect_fields(context, selections : Array(::GraphQL::Language::Selection), fields : Array(::GraphQL::Language::Field), errors : Array(::GraphQL::Error), visited_fragments = [] of String) : Nil
    selections.each do |selection|
      case selection
      when ::GraphQL::Language::Field
        path = selection._alias || selection.name
        next if _graphql_skip?(selection, selection.directives, [path] of String | Int32, errors)
        if index = fields.index { |f| (f._alias || f.name) == path }
          next if selection.selections.empty?
          merged = fields[index].dup
          merged.selections = fields[index].selections + selection.selections
          fields[index] = merged
        else
          fields << selection
        end
      when ::GraphQL::Language::FragmentSpread
        next if _graphql_skip?(selection, selection.directives, [selection.name] of String | Int32, errors)
        if visited_fragments.includes?(selection.name)
          errors << ::GraphQL::Error.new("fragment #{selection.name} spreads itself", selection.name, selection)
        elsif fragment = context.fragments.find { |f| f.name == selection.name }
          next unless _graphql_type_condition_matches?(fragment.type)
          _graphql_collect_fields(context, fragment.selections, fields, errors, visited_fragments + [selection.name])
        else
          errors << ::GraphQL::Error.new("no fragment #{selection.name}", selection.name, selection)
        end
      when ::GraphQL::Language::InlineFragment
        next if _graphql_skip?(selection, selection.directives, nil, errors)
        next unless _graphql_type_condition_matches?(selection.type)
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
  # :nodoc:
  # Whether `selections` can be used as the field list as is: only fields,
  # no directives, no two fields sharing a response key. Most selection
  # sets qualify, and skipping the collection step saves an array per
  # object.
  private def _graphql_plain_fields?(selections : Array(::GraphQL::Language::Selection)) : Bool
    return false if selections.size > 8

    selections.each_with_index do |selection, i|
      return false unless selection.is_a?(::GraphQL::Language::Field) && selection.directives.empty?
      key = selection._alias || selection.name
      i.times do |j|
        earlier = selections[j].as(::GraphQL::Language::Field)
        return false if (earlier._alias || earlier.name) == key
      end
    end

    true
  end

  protected def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection), json : JSON::Builder, serial : Bool = false) : Array(::GraphQL::Error)
    errors = [] of ::GraphQL::Error
    fields = if _graphql_plain_fields?(selections)
               selections
             else
               collected = [] of ::GraphQL::Language::Field
               _graphql_collect_fields(context, selections, collected, errors)
               collected
             end

    return _graphql_resolve_sequentially(context, fields, json, errors) if serial || context.max_concurrency == 0

    pending = Array(PendingFragment).new(fields.size)
    fields.each do |selection|
      field = selection.as(::GraphQL::Language::Field)
      path = field._alias || field.name
      pending << _graphql_fork(context, serial) do
        _graphql_build_json_fragment(context, path, field) do |field_json|
          _graphql_resolve(context, field, field_json)
        end
      end
    end

    propagate = false

    fields.each_with_index do |selection, i|
      field = selection.as(::GraphQL::Language::Field)
      path = field._alias || field.name
      fragment = _graphql_await(pending[i])
      errors.concat fragment.errors

      if fragment.json.empty?
        propagate = true unless _graphql_field_nullable?(field.name)
        json.field(path) { json.null }
      else
        json.field(path) { json.raw fragment.json }
      end
    end

    raise NullPropagation.new(errors) if propagate
    errors
  end

  # :nodoc:
  # Resolves every field in this fiber, in order. Leaf values are written
  # straight into `json` once resolved, since nothing can fail after their
  # key is emitted; object values still go through a buffer so a failing
  # non-null descendant can discard the partial output.
  private def _graphql_resolve_sequentially(context, fields : Array(::GraphQL::Language::Selection) | Array(::GraphQL::Language::Field), json : JSON::Builder, errors : Array(::GraphQL::Error)) : Array(::GraphQL::Error)
    propagate = false

    fields.each do |selection|
      field = selection.as(::GraphQL::Language::Field)
      path = field._alias || field.name
      failed = false

      if _graphql_leaf_field?(field.name)
        failed = _graphql_resolve_leaf(context, field, path, json, errors)
      else
        fragment = _graphql_build_json_fragment(context, path, field) do |field_json|
          _graphql_resolve(context, field, field_json)
        end
        errors.concat fragment.errors
        failed = fragment.json.empty?
        json.field(path) { failed ? json.null : json.raw(fragment.json) }
      end

      propagate = true if failed && !_graphql_field_nullable?(field.name)
    end

    raise NullPropagation.new(errors) if propagate
    errors
  end

  # :nodoc:
  # Writes an already resolved leaf value under `path`, or null when it
  # cannot be represented. Returns whether the field failed.
  private def _graphql_write_leaf(context, field : ::GraphQL::Language::Field, path : String, value, json : JSON::Builder, errors : Array(::GraphQL::Error)) : Bool
    if value.is_a?(Array) && !_graphql_finite?(value)
      # the buffered path reports and nulls the offending elements
      fragment = _graphql_build_json_fragment(context, path, field) do |field_json|
        list_errors = _graphql_serialize(context, field, value, field_json)
        list_errors.each &.with_path(path)
        list_errors
      end
      errors.concat fragment.errors
      failed = fragment.json.empty?
      json.field(path) { failed ? json.null : json.raw(fragment.json) }
      failed
    elsif !_graphql_finite?(value)
      errors << ::GraphQL::Error.new("Float cannot represent non-finite value", [path] of String | Int32, field)
      json.field(path) { json.null }
      true
    else
      json.field(path) do
        leaf_errors = _graphql_serialize(context, field, value, json)
        unless leaf_errors.empty?
          leaf_errors.each &.with_path(path)
          errors.concat leaf_errors
        end
      end
      false
    end
  end

  # :nodoc:
  # A leaf resolver raised before anything was written: record the error
  # the way the buffered path would and emit null.
  private def _graphql_leaf_failed(context, error : ::Exception, field : ::GraphQL::Language::Field, path : String, json : JSON::Builder, errors : Array(::GraphQL::Error)) : Bool
    if message = context.handle_exception(error)
      errors << ::GraphQL::Error.new(message, [path] of String | Int32, field)
    end
    json.field(path) { json.null }
    true
  end

  # :nodoc:
  # JSON cannot represent NaN or infinities; the builder raises mid-write,
  # so leaf values are checked before their key is emitted.
  private def _graphql_finite?(value) : Bool
    case value
    when Float64                   then value.finite?
    when ::GraphQL::Scalars::Float then value.value.finite?
    when Array                     then value.all? { |v| _graphql_finite?(v) }
    else                                true
    end
  end

  # :nodoc:
  # Whether every element of the list is a built-in scalar, enum or nil,
  # whose serialization cannot fail once started.
  private def _graphql_leaf_elements?(value : Array) : Bool
    value.all? do |v|
      v.is_a?(String | Int32 | Float64 | Bool?) || v.is_a?(::Enum) ||
        v.is_a?(::GraphQL::Scalars::String | ::GraphQL::Scalars::Boolean | ::GraphQL::Scalars::Int | ::GraphQL::Scalars::Float | ::GraphQL::Scalars::ID | ::GraphQL::Scalars::BigInt)
    end
  end

  # :nodoc:
  # Resolves a root selection set into a JSON fragment. The fragment's JSON
  # is empty when a non-null root field failed, in which case `data` must be
  # null.
  def _graphql_execute(context, selections : Array(::GraphQL::Language::Selection), serial : Bool = false) : JSONFragment
    _graphql_build_json_fragment(context, [] of String | Int32) do |json|
      errors = NO_ERRORS
      json.object do
        errors = _graphql_resolve(context, selections, json, serial)
      end
      errors
    end
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
  # Builds one value into its own JSON string. An empty string marks a failed
  # fragment, which the caller renders as null or propagates further up.
  # `path` is the prefix the caller would otherwise add to the block's
  # errors, so exceptions can be reported at the same place.
  private def _graphql_build_json_fragment(context, path : String | Int32 | Array(Int32 | String), node : ::GraphQL::Language::ASTNode? = nil, & : JSON::Builder -> Array(::GraphQL::Error)) : JSONFragment
    errors = NO_ERRORS
    failed = false

    json = String.build do |io|
      builder = JSON::Builder.new(io)
      builder.document do
        errors = yield builder
      end
    rescue e : NullPropagation
      failed = true
      e.errors.each { |error| _graphql_prefix_path(error, path) }
      errors = e.errors
    rescue e
      failed = true
      if message = context.handle_exception(e)
        error_path = path.is_a?(Array) ? path : [path] of String | Int32
        errors = [::GraphQL::Error.new(message, error_path.empty? ? nil : error_path, node)]
      end
    end

    # whatever was written before the exception is discarded
    JSONFragment.new(failed ? "" : json, errors)
  end

  # :nodoc:
  private def _graphql_prefix_path(error : ::GraphQL::Error, path : String | Int32 | Array(Int32 | String)) : Nil
    case path
    when String, Int32
      error.with_path(path)
    else
      path.reverse_each { |segment| error.with_path(segment) }
    end
  end
end

module GraphQL::ObjectType
  # :nodoc:
  # Forwards each value from `source` as one response document. The
  # subscription ends when `source` closes; closing the subscription closes
  # `source`, which also wakes the forwarding fiber.
  protected def _graphql_forward(context, field : ::GraphQL::Language::Field, source : Channel(T)) : ::GraphQL::Subscription forall T
    output = Channel(String).new
    path = field._alias || field.name
    nullable = _graphql_field_nullable?(field.name)

    spawn do
      loop do
        value = source.receive
        output.send _graphql_render_event(context, field, path, nullable, value)
      end
    rescue Channel::ClosedError
      # either side is done
    rescue ex
      message = context.handle_exception(ex)
      output.send({"errors" => [::GraphQL::Error.new(message || "subscription failed", path, field)]}.to_json) rescue nil
    ensure
      source.close
      output.close
    end

    ::GraphQL::Subscription.new(output) { source.close }
  end

  # :nodoc:
  private def _graphql_render_event(context, field : ::GraphQL::Language::Field, path : String, nullable : Bool, value) : String
    fragment = _graphql_build_json_fragment(context, path, field) do |json|
      _graphql_serialize(context, field, value, json).map &.with_path(path)
    end

    JSON.build do |json|
      json.object do
        json.field "data" do
          if fragment.json.empty? && !nullable
            json.null
          else
            json.object do
              json.field(path) { fragment.json.empty? ? json.null : json.raw(fragment.json) }
            end
          end
        end
        unless fragment.errors.empty?
          json.field("errors") { fragment.errors.to_json(json) }
        end
      end
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
