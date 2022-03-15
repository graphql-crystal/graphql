require "./internal/convert_value"

module GraphQL::InputObjectType
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def self._graphql_new(input_object : ::GraphQL::Language::InputObject)
        {% method = @type.methods.find(&.annotation(::GraphQL::Field)) %}
        self.new(
          {% for arg in method.args %}
            {{arg.name}}: begin
              fa = input_object.arguments.find { |i| i.name == {{ arg.name.stringify.camelcase(lower: true) }} }
              if fa.nil? || fa.value.nil?
                {% if !(arg.default_value.is_a? Nop) %}
                  {{arg.default_value}}
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise ::GraphQL::TypeError.new("missing required input value {{ arg.name.camelcase(lower: true) }}")
                {% end %}
              else
                ::GraphQL::Internal.convert_value {{ arg.restriction.resolve.union_types.find { |t| t != Nil } }}, fa.value, {{ arg.name.camelcase(lower: true) }}
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
