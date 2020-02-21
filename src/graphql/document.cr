module GraphQL::Document
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def _graphql_document
        {% raise "#{@type.id} does not have a GraphQL::Object annotation" unless @type.annotation(::GraphQL::Object) %}
        {% objects = [@type, ::GraphQL::Introspection::Schema] %}
        {% enums = [] of TypeNode %}

        {% for i in (0..1000) %}
          {% if objects[i] %}
            {% for method in (objects[i].resolve.methods.reject { |m| m.annotation(::GraphQL::Field) == nil }) %}
              {% if method.return_type.is_a?(Nop) && !objects[i].annotation(::GraphQL::InputObject) %}
                {% raise "#{objects[i].name.id}##{method.name.id} must have a return type" %}
              {% end %}
              {% for arg in method.args %}
                {% for type in arg.restriction.resolve.union_types %}
                  {% if type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context) %}
                    {% objects << type.resolve %}
                  {% end %}
                  {% for inner_type in type.type_vars %}
                    {% if inner_type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(inner_type.resolve) && !(inner_type.resolve < ::GraphQL::Context) %}
                      {% objects << inner_type.resolve %}
                    {% end %}
                  {% end %}
                {% end %}
              {% end %}
              {% if objects[i].annotation(::GraphQL::Object) %}
                {% for type in method.return_type.types %}
                  {% if type.resolve < Array %}
                    {% for inner_type in type.resolve.type_vars %}
                      {% if (inner_type.resolve.annotation(::GraphQL::Object) || inner_type.resolve.annotation(::GraphQL::InputObject)) && !objects.includes?(inner_type.resolve) %}
                        {% objects << inner_type.resolve %}
                      {% end %}
                      {% if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve) %}
                        {% enums << inner_type.resolve %}
                      {% end %}
                    {% end %}
                  {% end %}
                  {% if (type.resolve.annotation(::GraphQL::Object) || type.resolve.annotation(::GraphQL::InputObject)) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context) %}
                    {% objects << type.resolve %}
                  {% end %}
                  {% if type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(type.resolve) %}
                    {% enums << type.resolve %}
                  {% end %}
                {% end %}
              {% end %}
            {% end %}
          {% end %}
        {% end %}
        {% raise "document object limit reached" unless objects.size < 1000 %}

        %type : ::GraphQL::Language::Type | ::GraphQL::Language::ListType | ::GraphQL::Language::TypeName
        %definitions = [] of ::GraphQL::Language::TypeDefinition

        {% for object in objects %}
          %fields = [] of ::GraphQL::Language::FieldDefinition
          {% for method in (object.methods.select { |m| m.annotation(::GraphQL::Field) }) %}
            %input_values = [] of ::GraphQL::Language::InputValueDefinition
            {% for arg in method.args %}
              {% types = [] of TypeNode %}
              {% for type in arg.restriction.resolve.union_types %}
                {% if !(type < ::GraphQL::Context) && type != Nil %}
                  {% types.unshift(type) %}
                {% elsif type == Nil %}
                  {% types.push(type) %}
                {% end %}
              {% end %}
              {% types.push Nil if types.last != Nil && !arg.default_value.is_a?(Nop) %}
              {% if !types.empty? %}
                {% for type in types.first.type_vars %}
                  {% types.unshift type %}
                {% end %}
              {% end %}
              {% types.push Nil if types.last != Nil && !arg.default_value.is_a?(Nop) %}

              # we may want some type validation here?
              {% for type in types %}
                {% if type < ::Object && type.annotation(::GraphQL::Object) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
                {% elsif type < ::Enum && type.annotation(::GraphQL::Enum) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Enum)["name"] || type.name.split("::").last }})
                {% elsif type < ::Object && type.annotation(::GraphQL::InputObject) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::InputObject)["name"] || type.name.split("::").last }})
                {% elsif type == String %}
                  %type = ::GraphQL::Language::TypeName.new(name: "String")
                {% elsif type < Int %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Int")
                {% elsif type < Float %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Float")
                {% elsif type == Bool %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Boolean")
                {% elsif type < Array %}
                  %type = ::GraphQL::Language::ListType.new(of_type: %type.dup)
                {% elsif type != Nil %}
                  {% raise "#{object.name}##{arg.name} type #{type} is not a GraphQL type" %}
                {% end %}

                {% if type != Nil %}
                  # we don't know yet if type is nullable or not so we assume it's not
                  %type = ::GraphQL::Language::NonNullType.new(of_type: %type.dup) unless %type.is_a? ::GraphQL::Language::NonNullType
                {% else %}
                  # type is nullable, undo NonNullType
                  %type = %type.of_type.dup
                {% end %}
              {% end %}
              {% if !types.empty? %}
                %input_values << ::GraphQL::Language::InputValueDefinition.new(
                  name: {{ arg.name.id.stringify.camelcase(lower: true) }},
                  type: %type,
                  default_value: nil, # TODO?
                  directives: [] of ::GraphQL::Language::Directive,
                  description: nil, # "Arg Description",
                )
              {% end %}
            {% end %}

            {% types = [] of TypeNode %}
            {% if !object.annotation(::GraphQL::InputObject) %}
              {% for type in method.return_type.resolve.union_types %}
                {% if !(type < ::GraphQL::Context) && type != Nil %}
                  {% types.unshift(type) %}
                {% elsif type == Nil %}
                  {% types.push(type) %}
                {% end %}
              {% end %}
              {% if !types.empty? %}
                {% for type in types.first.type_vars %}
                  {% types.unshift type %}
                {% end %}
              {% end %}
            {% end %}

            {% for type in types %}

              {% if type < ::Object && type.annotation(::GraphQL::Object) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
              {% elsif type < ::Enum && type.annotation(::GraphQL::Enum) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Enum)["name"] || type.name.split("::").last }})
              {% elsif type < ::Object && type.annotation(::GraphQL::InputObject) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::InputObject)["name"] || type.name.split("::").last }})
              {% elsif type == String %}
                %type = ::GraphQL::Language::TypeName.new(name: "String")
              {% elsif type < Int %}
                %type = ::GraphQL::Language::TypeName.new(name: "Int")
              {% elsif type < Float %}
                %type = ::GraphQL::Language::TypeName.new(name: "Float")
              {% elsif type == Bool %}
                %type = ::GraphQL::Language::TypeName.new(name: "Boolean")
              {% elsif type < Array %}
                %type = ::GraphQL::Language::ListType.new(of_type: %type.dup)
              {% elsif type != Nil %}
                {% raise "#{object.name}##{method.name} type #{type} is not a GraphQL type" %}
              {% end %}

              {% if type != Nil %}
                %type = ::GraphQL::Language::NonNullType.new(of_type: %type.dup) unless %type.is_a? ::GraphQL::Language::NonNullType
              {% else %}
                %type = %type.of_type.dup
              {% end %}
            {% end %}
            {% if !types.empty? %}
              %directives = [] of ::GraphQL::Language::Directive
              {% if method.annotation(::GraphQL::Field)["deprecated"] %}
                %directives << ::GraphQL::Language::Directive.new(
                  name: "deprecated",
                  arguments: [GraphQL::Language::Argument.new("reason", {{method.annotation(::GraphQL::Field)["deprecated"]}})]
                )
              {% end %}
              %fields << ::GraphQL::Language::FieldDefinition.new(
                name: {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }},
                arguments: %input_values.sort{|a, b| a.name <=> b.name },
                type: %type,
                directives: %directives,
                description: {{ method.annotation(::GraphQL::Field)["description"] }},
              )
            {% end %}
          {% end %}

          {% if object.annotation(::GraphQL::Object) %}
            %definitions << ::GraphQL::Language::ObjectTypeDefinition.new(
              name: {{ object.annotation(::GraphQL::Object)["name"] || object.name.split("::").last }},
              fields: %fields.sort{|a, b| a.name <=> b.name },
              interfaces: [] of String?,
              directives: [] of ::GraphQL::Language::Directive,
              description: {{ object.annotation(::GraphQL::Object)["description"] }},
            )
          {% elsif object.annotation(::GraphQL::InputObject) %}
            %definitions << ::GraphQL::Language::InputObjectTypeDefinition.new(
              name: {{ object.annotation(::GraphQL::InputObject)["name"] || object.name.split("::").last }},
              fields: %input_values,
              directives: [] of ::GraphQL::Language::Directive,
              description: {{ object.annotation(::GraphQL::InputObject)["description"] }},
            )
          {% else %}
            {% raise "unknown object type ??? #{object.name}" %}
          {% end %}
        {% end %}

        {% for e_num in enums %}
          %definitions << ::GraphQL::Language::EnumTypeDefinition.new(
            name: {{ e_num.annotation(::GraphQL::Enum)["name"] || e_num.name.split("::").last }},
            description: {{ e_num.annotation(::GraphQL::Enum)["description"] }},
            fvalues: ([
              {% for constant in e_num.resolve.constants %}
              ::GraphQL::Language::EnumValueDefinition.new(
                name: {{ constant.stringify }},
                directives: [] of ::GraphQL::Language::Directive,
                selection: nil,
                description: nil, # TODO
              ),
              {% end %}
          ] of ::GraphQL::Language::EnumValueDefinition).sort {|a, b| a.name <=> b.name },
            directives: [] of ::GraphQL::Language::Directive,
          )
        {% end %}


        %scalars = {
          {"String", "A String Value"},
          {"Boolean", "A Boolean Value"},
          {"Int", "An Integer Number"},
          {"Float", "A Floating Point Number"},
          {"ID", "An ID"},
        }
        %scalars.each do |%name, %description|
          %definitions << ::GraphQL::Language::ScalarTypeDefinition.new(
            name: %name,
            description: %description,
            directives: [] of ::GraphQL::Language::Directive
          )
        end

        ::GraphQL::Language::Document.new(%definitions.sort { |a, b| a.name <=> b.name })
      end
      {% end %}
    end
  end
end
