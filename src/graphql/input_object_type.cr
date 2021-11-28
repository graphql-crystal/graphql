module GraphQL::InputObjectType
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def self._graphql_new(input_object : ::GraphQL::Language::InputObject)
        {% method = @type.methods.find { |m| m.annotation(::GraphQL::Field) } %}
        self.new(
          {% for arg in method.args %}
            {{arg.name}}: begin
              arg = input_object.arguments.find{|i| i.name == {{ arg.name.stringify.camelcase(lower: true) }}}
              if arg.nil? || arg.value.nil?
                {% if !(arg.default_value.is_a? Nop) %}
                  {{arg.default_value}}
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise "GraphQL: missing required input value {{ arg.name.camelcase(lower: true) }}"
                {% end %}
              else
                {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
                case arg_value = arg.value
                {% if type < Float %}
                when Int, Float
                  arg_value.to_f64.as({{type}})
                {% elsif type < Int %}
                when Int
                  arg_value.as({{type}})
                {% elsif type.annotation(::GraphQL::InputObject) %}
                when ::GraphQL::Language::InputObject
                  {{type}}._graphql_new(arg.value.as(::GraphQL::Language::InputObject))
                {% elsif type.annotation(::GraphQL::Enum) %}
                when ::GraphQL::Language::AEnum
                    {{type}}.parse(arg_value.to_value)
                when String
                  {{type}}.parse(arg_value)
                {% elsif type < Array %}
                {% inner_type = type.type_vars.find { |t| t != Nil }.resolve %}
                when Array
                  arg_value.map do |value|
                    case value
                    {% if inner_type < Float %}
                    when Int, Float
                      value.to_f64.as({{inner_type}})
                    {% elsif inner_type < Int %}
                    when Int
                      value.as({{inner_type}})
                    {% elsif inner_type.annotation(::GraphQL::InputObject) %}
                    when ::GraphQL::Language::InputObject
                      {{inner_type}}._graphql_new(value)
                    {% elsif inner_type.annotation(::GraphQL::Enum) %}
                    when ::GraphQL::Language::AEnum
                    {{type}}.parse(arg_value.to_value)
                    when String
                      {{type}}.parse(arg_value)
                    {% elsif inner_type < Array %}
                      {% raise "GraphQL: #{@type.name}##{method.name} nested arrays are not supported" %}
                    {% end %}
                    when {{inner_type}}
                      value
                    else
                      raise TypeCastError.new # signals invalid type to resolver
                    end.as({{inner_type}})
                  end.as(Array({{inner_type}}))
                {% end %}
                when {{type}}
                  arg_value
                else
                  raise TypeCastError.new # signals invalid type to resolver
                end
              end
            end,
          {% end %}
        )
      end
      {% end %}
    end
  end
end

module GraphQL
  abstract class BaseInputObject
    macro inherited
      include GraphQL::InputObjectType
    end
  end
end
