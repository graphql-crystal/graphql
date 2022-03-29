require "./introspection"
require "./scalars"

module GraphQL::Document
  private macro _graphql_t(t, nilable)
    {% type = t.resolve %}
    {% unless nilable %}
    ::GraphQL::Language::NonNullType.new(of_type:
    {% end %}
      {% if type < ::Object && type.annotation(::GraphQL::Object) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
      {% elsif type < ::Enum && type.annotation(::GraphQL::Enum) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Enum)["name"] || type.name.split("::").last }})
      {% elsif type < ::Object && type.annotation(::GraphQL::InputObject) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::InputObject)["name"] || type.name.split("::").last }})
      {% elsif type < ::Object && type.annotation(::GraphQL::Scalar) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Scalar)["name"] || type.name.split("::").last }})
      {% elsif type == String %}
        ::GraphQL::Language::TypeName.new(name: "String")
      {% elsif type == Int32 %}
        ::GraphQL::Language::TypeName.new(name: "Int")
      {% elsif type < Float %}
        ::GraphQL::Language::TypeName.new(name: "Float")
      {% elsif type == Bool %}
        ::GraphQL::Language::TypeName.new(name: "Boolean")
      {% elsif type < Array %}
        {% inner = type.type_vars.find { |t| t != Nil } %}
        ::GraphQL::Language::ListType.new(of_type: _graphql_t({{ inner }}, {{ inner.nilable? }}))
      {% else %}
        {% raise "GraphQL: #{type} is not a GraphQL type" %}
      {% end %}
    {% unless nilable %}
    )
    {% end %}
  end

  private macro _graphql_input_def(t, nilable, default, name, description)
    {% type = t.resolve %}
    ::GraphQL::Language::InputValueDefinition.new(
      name: {{ name }},
      description: {{ description }},
      type: (_graphql_t {{ type }}, {{ nilable }}),
      {% if type.annotation(::GraphQL::Enum) %}
      default_value: {{default}}.nil? ? nil : ::GraphQL::Language::AEnum.new(name: {{default}}.to_s),
      {% else %}
      default_value: {{default}},
      {% end %}
      directives: [] of ::GraphQL::Language::Directive,
    )
  end

  macro included
    macro finished
      {% verbatim do %}
      {% verbatim do %}
      # :nodoc:
      def _graphql_document
        {% begin %}
        {%
          objects = [@type, ::GraphQL::Introspection::Schema]
          enums = [] of TypeNode
          scalars = [::GraphQL::Scalars::String, ::GraphQL::Scalars::Boolean, ::GraphQL::Scalars::Float, ::GraphQL::Scalars::Int, ::GraphQL::Scalars::ID] of TypeNode

          (0..1000).each do |i|
            if objects[i]
              objects[i].instance_vars.select(&.annotation(::GraphQL::Field)).each do |prop|
                prop.type.resolve.union_types.each do |type|
                  if type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context)
                    objects << type.resolve
                  end

                  if type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(type.resolve)
                    enums << type.resolve
                  end

                  if type.resolve.annotation(::GraphQL::Scalar) && !scalars.includes?(type.resolve)
                    scalars << type.resolve
                  end

                  type.type_vars.each do |inner_type|
                    if inner_type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(inner_type.resolve) && !(inner_type.resolve < ::GraphQL::Context)
                      objects << inner_type.resolve
                    end
                    if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve)
                      enums << inner_type.resolve
                    end
                  end
                end
              end

              objects[i].methods.select(&.annotation(::GraphQL::Field)).each do |method|
                if method.return_type.is_a?(Nop) && !objects[i].annotation(::GraphQL::InputObject)
                  raise "GraphQL: #{objects[i].name.id}##{method.name.id} must have a return type"
                end

                method.args.each do |arg|
                  arg.restriction.resolve.union_types.each do |type|
                    if type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context)
                      objects << type.resolve
                    end

                    if type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(type.resolve)
                      enums << type.resolve
                    end

                    if type.resolve.annotation(::GraphQL::Scalar) && !scalars.includes?(type.resolve)
                      scalars << type.resolve
                    end

                    type.type_vars.each do |inner_type|
                      if inner_type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(inner_type.resolve) && !(inner_type.resolve < ::GraphQL::Context)
                        objects << inner_type.resolve
                      end
                      if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve)
                        enums << inner_type.resolve
                      end
                    end
                  end
                end

                if objects[i].annotation(::GraphQL::Object)
                  method.return_type.types.each do |type|
                    if type.resolve < Array
                      type.resolve.type_vars.each do |inner_type|
                        if (inner_type.resolve.annotation(::GraphQL::Object) || inner_type.resolve.annotation(::GraphQL::InputObject)) && !objects.includes?(inner_type.resolve)
                          objects << inner_type.resolve
                        end

                        if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve)
                          enums << inner_type.resolve
                        end
                        if inner_type.resolve.annotation(::GraphQL::Scalar) && !scalars.includes?(inner_type.resolve)
                          scalars << inner_type.resolve
                        end
                      end
                    end

                    if (type.resolve.annotation(::GraphQL::Object) || type.resolve.annotation(::GraphQL::InputObject)) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context)
                      objects << type.resolve
                    end

                    if type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(type.resolve)
                      enums << type.resolve
                    end

                    if type.resolve.annotation(::GraphQL::Scalar) && !scalars.includes?(type.resolve)
                      scalars << type.resolve
                    end
                  end
                end
              end
            end
          end

          raise "GraphQL: document object limit reached" unless objects.size < 1000
        %}

        %definitions = [] of ::GraphQL::Language::TypeDefinition

        {% for object in objects %}
          %fields = [] of ::GraphQL::Language::FieldDefinition

          {% for var in object.instance_vars.select(&.annotation(::GraphQL::Field)) %}
            %directives = [] of ::GraphQL::Language::Directive
            {% if var.annotation(::GraphQL::Field)["deprecated"] %}
              %directives << ::GraphQL::Language::Directive.new(
                name: "deprecated",
                arguments: [GraphQL::Language::Argument.new("reason", {{var.annotation(::GraphQL::Field)["deprecated"]}})]
              )
            {% end %}
            %fields << ::GraphQL::Language::FieldDefinition.new(
              name: {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }},
              arguments: [] of ::GraphQL::Language::InputValueDefinition,
              type: (_graphql_t {{ var.type.union_types.find { |t| t != Nil } }}, {{ var.type.nilable? }}),
              directives: %directives,
              description: {{ var.annotation(::GraphQL::Field)["description"] }},
            )
          {% end %}

          {% for method in object.methods.select(&.annotation(::GraphQL::Field)) %}
            %input_values = [] of ::GraphQL::Language::InputValueDefinition
            {% for arg in method.args %}
              {% unless arg.restriction.resolve < ::GraphQL::Context || arg.restriction.resolve == ::GraphQL::Context %}
                {%
                  ann_args = method.annotation(::GraphQL::Field)["arguments"]
                  ann_arg = ann_args && ann_args[arg.name.id]
                %}
                %input_values << (_graphql_input_def(
                  {{ arg.restriction.resolve.union_types.find { |t| t != Nil } }},
                  {{ arg.restriction.resolve.nilable? }},
                  {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }},
                  {{ ann_arg && ann_arg["name"] || arg.name.id.stringify.camelcase(lower: true) }},
                  {{ ann_arg && ann_arg["description"] || nil }},
                ))
              {% end %}
            {% end %}

            {% if !object.annotation(::GraphQL::InputObject) %}
              {% type = method.return_type.resolve %}
              {% if !(type < ::GraphQL::Context) && type != Nil %}
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
                  type: (_graphql_t {{ type.union_types.find { |t| t != Nil } }}, {{ type.nilable? }}),
                  directives: %directives,
                  description: {{ method.annotation(::GraphQL::Field)["description"] }},
                )
              {% end %}
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
            {% raise "GraphQL: unknown object type ??? #{object.name}" %}
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

        {% for scalar in scalars %}
          %definitions << ::GraphQL::Language::ScalarTypeDefinition.new(
            name: {{ scalar.annotation(::GraphQL::Scalar)["name"] || scalar.name.split("::").last }},
            description: {{ scalar.annotation(::GraphQL::Scalar)["description"] }},
            directives: [] of ::GraphQL::Language::Directive
          )
        {% end %}

        ::GraphQL::Language::Document.new(%definitions.sort { |a, b| a.name <=> b.name })
        {% end %}
      end
      {% end %}
      {% end %}
    end
  end

end
