module GraphQL::Internal
  macro convert_value(t, value, name)
    {% type = t.resolve %}
    case %value = {{value}}
    when {{type}}
      %value
    {% if type == Float64 %}
    when Int32
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
    when String, Int32, Float64
      {{type}}.from_json(%value.to_json)
    {% elsif type < Array %}
    when Array
      {% inner_type = type.type_vars.find { |t| t != Nil } %}
      %value.map do |%v|
        ::GraphQL::Internal.convert_value {{ inner_type }}, %v, name
      end
    {% end %}
    else
      raise ::GraphQL::TypeError.new("bad type for argument {{ name }}")
    end.as({{type}})
  end
end
