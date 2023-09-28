module GraphQL::Document
  macro included
    macro finished
      {% verbatim do %}
      # :nodoc:
      def _graphql_document
        {%
          a = 1 # XXX: compiler raises error when if statement first

          unless @type.annotation(::GraphQL::Object)
            raise "GraphQL: #{@type.id} does not have a GraphQL::Object annotation"
          end

          objects = [@type, ::GraphQL::Introspection::Schema]
          enums = [] of TypeNode
          scalars = [::GraphQL::Scalars::String, ::GraphQL::Scalars::Boolean, ::GraphQL::Scalars::Float, ::GraphQL::Scalars::Int, ::GraphQL::Scalars::Int64, ::GraphQL::Scalars::ID] of TypeNode

          (0..1000).each do |i|
            if objects[i]
              selected_methods = objects[i].resolve.methods.reject { |m| m.annotation(::GraphQL::Field) == nil }
              selected_methods.each do |method|
                if method.return_type.is_a?(Nop) && !objects[i].annotation(::GraphQL::InputObject)
                  raise "GraphQL: #{objects[i].name.id}##{method.name.id} must have a return type"
                end

                method.args.each do |arg|
                  arg.restriction.resolve.union_types.each do |type|
                    if type.resolve < Array
                      type.resolve.type_vars.each do |inner_type|
                        if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve)
                          enums << inner_type.resolve
                        end
                      end
                    end

                    if type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(type.resolve) && !(type.resolve < ::GraphQL::Context)
                      objects << type.resolve
                    end

                    if type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(type.resolve)
                      enums << type.resolve
                    end

                    type.type_vars.each do |inner_type|
                      if inner_type.resolve.annotation(::GraphQL::InputObject) && !objects.includes?(inner_type.resolve) && !(inner_type.resolve < ::GraphQL::Context)
                        objects << inner_type.resolve
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

        %type : ::GraphQL::Language::Type | ::GraphQL::Language::ListType | ::GraphQL::Language::TypeName
        %definitions = [] of ::GraphQL::Language::TypeDefinition

        {% for object in objects %}
          %fields = [] of ::GraphQL::Language::FieldDefinition
          {% for method in (object.methods.select { |m| m.annotation(::GraphQL::Field) }) %}
            %input_values = [] of ::GraphQL::Language::InputValueDefinition
            {% for arg in method.args %}
              {%
                types = [] of TypeNode

                arg.restriction.resolve.union_types.each do |type|
                  if !(type < ::GraphQL::Context) && type != Nil
                    types.unshift(type)
                  elsif type == Nil
                    types.push(type)
                  end
                end

                types.push Nil if types.last != Nil && !arg.default_value.is_a?(Nop)

                if !types.empty?
                  types.first.type_vars.each do |type|
                    types.unshift type
                  end
                end

                types.push Nil if types.last != Nil && !arg.default_value.is_a?(Nop)
              %}

              # we may want some type validation here?
              {% for type in types %}
                {% if type < ::Object && type.annotation(::GraphQL::Object) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type < ::Enum && type.annotation(::GraphQL::Enum) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Enum)["name"] || type.name.split("::").last }})
                  %dv = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                  %default_value = %dv.nil? ? nil : ::GraphQL::Language::AEnum.new(name: %dv.to_s)
                {% elsif type < ::Object && type.annotation(::GraphQL::InputObject) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::InputObject)["name"] || type.name.split("::").last }})
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type == String %}
                  %type = ::GraphQL::Language::TypeName.new(name: "String")
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type < Int %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Int")
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type < Float %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Float")
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type == Bool %}
                  %type = ::GraphQL::Language::TypeName.new(name: "Boolean")
                  %default_value = {{ arg.default_value.is_a?(Nop) ? nil : arg.default_value }}
                {% elsif type < Array %}
                  %type = ::GraphQL::Language::ListType.new(of_type: %type.dup)
                {% elsif type != Nil %}
                  {% raise "GraphQL: #{object.name}##{arg.name} type #{type} is not a GraphQL type" %}
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
                  name: {{ method.annotation(::GraphQL::Field)["arguments"] && method.annotation(::GraphQL::Field)["arguments"][arg.name.id] && method.annotation(::GraphQL::Field)["arguments"][arg.name.id]["name"] || arg.name.id.stringify.camelcase(lower: true) }},
                  type: %type,
                  default_value: %default_value,
                  directives: [] of ::GraphQL::Language::Directive,
                  description: {{ method.annotation(::GraphQL::Field)["arguments"] && method.annotation(::GraphQL::Field)["arguments"][arg.name.id] && method.annotation(::GraphQL::Field)["arguments"][arg.name.id]["description"] || nil }},
                )
              {% end %}
            {% end %}

            {%
              types = [] of TypeNode

              if !object.annotation(::GraphQL::InputObject)
                method.return_type.resolve.union_types.each do |type|
                  if !(type < ::GraphQL::Context) && type != Nil
                    types.unshift(type)
                  elsif type == Nil
                    types.push(type)
                  end
                end

                if !types.empty?
                  types.first.type_vars.each do |type|
                    types.unshift type
                  end
                end
              end
            %}

            {% for type in types %}
              {% if type < ::Object && type.annotation(::GraphQL::Object) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
              {% elsif type < ::Enum && type.annotation(::GraphQL::Enum) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Enum)["name"] || type.name.split("::").last }})
              {% elsif type < ::Object && type.annotation(::GraphQL::InputObject) %}
                %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::InputObject)["name"] || type.name.split("::").last }})
              {% elsif type < ::Object && type.annotation(::GraphQL::Scalar) %}
                  %type = ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Scalar)["name"] || type.name.split("::").last }})
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
                {% raise "GraphQL: #{object.name}##{method.name} type #{type} is not a GraphQL type" %}
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
          {% if !scalar.annotation(::GraphQL::Scalar)["_ignore"] %}
            %definitions << ::GraphQL::Language::ScalarTypeDefinition.new(
              name: {{ scalar.annotation(::GraphQL::Scalar)["name"] || scalar.name.split("::").last }},
              description: {{ scalar.annotation(::GraphQL::Scalar)["description"] }},
              directives: [] of ::GraphQL::Language::Directive
            )
          {% end %}
        {% end %}

        ::GraphQL::Language::Document.new(%definitions.sort { |a, b| a.name <=> b.name })
      end
      {% end %}
    end
  end
end
