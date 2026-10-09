require "./internal/convert_value"

module GraphQL::InputObjectType
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def self._graphql_new(input_object : ::GraphQL::Language::InputObject)
        {% method = @type.methods.find(&.annotation(::GraphQL::Field)) %}
        {% ann_args = method.annotation(::GraphQL::Field)["arguments"] %}
        {% arg_names = method.args.map { |a| (ann_args && ann_args[a.name.id] && ann_args[a.name.id]["name"]) || a.name.id.stringify.camelcase(lower: true) } %}
        {% type_name = (@type.annotation(::GraphQL::InputObject) && @type.annotation(::GraphQL::InputObject)["name"]) || @type.name.split("::").last %}
        input_object.arguments.each do |fa|
          {% if arg_names.empty? %}
          raise ::GraphQL::TypeError.new("unknown field #{fa.name} on input object {{ type_name.id }}")
          {% else %}
          raise ::GraphQL::TypeError.new("unknown field #{fa.name} on input object {{ type_name.id }}") unless {{ arg_names }}.includes?(fa.name)
          {% end %}
        end
        self.new(
          {% for arg, i in method.args %}
            {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
            {% gql_name = arg_names[i] %}
            {{ arg.name }}: begin
              fa = input_object.arguments.find { |i| i.name == {{ gql_name }} }
              if fa.nil? || fa.value.nil?
                {% if !(arg.default_value.is_a? Nop) %}
                  {{ arg.default_value }}
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise ::GraphQL::TypeError.new("missing required input value {{ gql_name.id }}")
                {% end %}
              else
                ::GraphQL::Internal.convert_value {{ arg.restriction.resolve.union_types.find { |t| t != Nil } }}, fa.value, {{ gql_name.id }}
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
