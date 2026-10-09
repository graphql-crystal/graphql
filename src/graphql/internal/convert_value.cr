module GraphQL::Internal
  # Converts a parsed argument value into the Crystal type `t`. `name` is
  # the argument's GraphQL name, used in error messages.
  macro convert_value(t, value, name)
    {% type = t.resolve %}
    case %value = {{value}}
    when {{type}}
      %value
    {% if type == Int32 %}
    when ::BigInt
      raise ::GraphQL::TypeError.new("Int cannot represent non 32-bit signed integer value: #{%value}")
    {% elsif type == Float64 %}
    when Int32, ::BigInt
      %value.to_f64.as({{type}})
    {% elsif type.annotation(::GraphQL::Enum) %}
    when ::GraphQL::Language::AEnum
      {{type}}.parse(%value.to_value)
    when String
      {{type}}.parse(%value)
    {% elsif type.annotation(::GraphQL::InputObject) %}
    when ::GraphQL::Language::InputObject
      {{type}}._graphql_new(%value.as(::GraphQL::Language::InputObject))
    {% elsif type < ::GraphQL::ScalarType %}
    when String, Int32, Float64, ::BigInt
      {{type}}.from_json(%value.to_json)
    {% elsif type < Array %}
      {% inner = type.type_vars.first %}
      {% inner_type = inner.union_types.find { |t| t != Nil } %}
    when Array
      %value.each_with_object({{type}}.new) do |%v, %list|
        {% if inner.nilable? %}
        %list << (%v.nil? ? nil : ::GraphQL::Internal.convert_value({{inner_type}}, %v, {{name}}))
        {% else %}
        %list << ::GraphQL::Internal.convert_value({{inner_type}}, %v, {{name}})
        {% end %}
      end
    when Nil
      raise ::GraphQL::TypeError.new("bad type for argument {{ name }}")
    else
      # input coercion: a single value stands for a one-element list
      {{type}}.new(1) << ::GraphQL::Internal.convert_value({{inner_type}}, %value, {{name}})
    {% end %}
    {% unless type < Array %}
    else
      raise ::GraphQL::TypeError.new("bad type for argument {{ name }}")
    {% end %}
    end.as({{type}})
  end
end
