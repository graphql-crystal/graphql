module GraphQL::InputObjectType
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def self._graphql_new(input_object : ::GraphQL::Language::InputObject)
        {% method = @type.methods.find { |m| m.annotation(::GraphQL::Field) } %}
        self.new(
          {% for arg in method.args %}
            {{arg.name.id}}: begin
              arg = input_object.arguments.find{|i| i.name == {{ arg.name.id.stringify.camelcase(lower: true) }}}
              if arg.nil? || arg.value.nil?
                {% if !(arg.default_value.is_a? Nop) %}
                  {{arg.default_value}}
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise "missing required input value {{ arg.name.id.camelcase(lower: true) }}"
                {% end %}
              else
                {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
                case arg_value = arg.value
                {% if type < Float %}
                when Int, Float
                  arg_value.to_f64.as({{type.id}})
                {% elsif type < Int %}
                when Int
                  arg_value.as({{type.id}})
                {% elsif type.annotation(::GraphQL::InputObject) %}
                when ::GraphQL::Language::InputObject
                  {{type.id}}._graphql_new(arg.value.as(::GraphQL::Language::InputObject))
                {% elsif type < Array %}
                {% inner_type = type.type_vars.find { |t| t != Nil }.resolve %}
                when Array
                  arg_value.map do |value|
                    case value
                    {% if inner_type < Float %}
                    when Int, Float
                      value.to_f64.as({{value.id}})
                    {% elsif inner_type < Int %}
                    when Int
                      value.as({{value.id}})
                    {% elsif inner_type.annotation(::GraphQL::InputObject) %}
                    when ::GraphQL::Language::InputObject
                      {{inner_type.id}}._graphql_new(value)
                    {% elsif inner_type < Array %}
                      {% raise "GraphQL: #{@type.name}##{method.name} nested arrays are not supported" %}
                    {% end %}
                    when {{inner_type.id}}
                      value
                    else
                      raise TypeCastError.new # signals invalid type to resolver
                    end
                  end
                {% end %}
                when {{type.id}}
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
