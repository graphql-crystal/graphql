require "./introspection"
require "./scalars"

module GraphQL::Document
  # :nodoc:
  # Converts a Crystal default value into the AST value type used by the
  # schema. Arrays need an element-wise copy because `Array(String)` is not
  # an `Array(FValue)`, and enums become enum value nodes.
  def self._graphql_fvalue(value : ::Enum) : ::GraphQL::Language::FValue
    ::GraphQL::Language::AEnum.new(name: value.to_s)
  end

  # :nodoc:
  def self._graphql_fvalue(value : Array) : ::GraphQL::Language::FValue
    value.map { |v| _graphql_fvalue(v).as(::GraphQL::Language::FValue) }
  end

  # :nodoc:
  def self._graphql_fvalue(value : Hash) : ::GraphQL::Language::FValue
    value.each_with_object({} of String => ::GraphQL::Language::FValue) do |(k, v), hash|
      hash[k.to_s] = _graphql_fvalue(v)
    end
  end

  # :nodoc:
  def self._graphql_fvalue(value : String | Int32 | Float64 | Bool | Nil | ::GraphQL::Language::AEnum | ::GraphQL::Language::InputObject) : ::GraphQL::Language::FValue
    value
  end

  # :nodoc:
  def self._graphql_fvalue(value : T) : ::GraphQL::Language::FValue forall T
    {% raise "GraphQL: #{T} cannot be used as a default value" %}
  end

  private macro _graphql_t(t, nilable)
    {% type = t.resolve %}
    {% if type < Channel %}
      {% inner = type.type_vars.first %}
      {% inner_type = inner.union_types.find { |t| t != Nil } %}
      _graphql_t({{ inner_type }}, {{ inner.nilable? }})
    {% else %}
    {% unless nilable %}
    ::GraphQL::Language::NonNullType.new(of_type:
    {% end %}
      {% if type < ::Object && type.annotation(::GraphQL::Object) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Object)["name"] || type.name.split("::").last }})
      {% elsif type.annotation(::GraphQL::Interface) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Interface)["name"] || type.name.split("::").last }})
      {% elsif type.annotation(::GraphQL::Union) %}
        ::GraphQL::Language::TypeName.new(name: {{ type.annotation(::GraphQL::Union)["name"] || type.name.split("::").last }})
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
        {% inner = type.type_vars.first %}
        {% inner_type = inner.union_types.find { |t| t != Nil } %}
        ::GraphQL::Language::ListType.new(of_type: _graphql_t({{ inner_type }}, {{ inner.nilable? }}))
      {% else %}
        {% raise "GraphQL: #{type} is not a GraphQL type" %}
      {% end %}
    {% unless nilable %}
    )
    {% end %}
    {% end %}
  end

  # :nodoc:
  def self._graphql_deprecated(reason : String | Bool | Nil) : Array(::GraphQL::Language::Directive)
    return [] of ::GraphQL::Language::Directive unless reason
    arguments = reason.is_a?(String) ? [::GraphQL::Language::Argument.new("reason", reason)] : [] of ::GraphQL::Language::Argument
    [::GraphQL::Language::Directive.new(name: "deprecated", arguments: arguments)]
  end

  private macro _graphql_input_def(t, nilable, default, name, description, deprecated = nil)
    {% type = t.resolve %}
    ::GraphQL::Language::InputValueDefinition.new(
      name: {{ name }},
      description: {{ description }},
      type: (_graphql_t {{ type }}, {{ nilable }}),
      default_value: ::GraphQL::Document._graphql_fvalue({{ default }}),
      directives: ::GraphQL::Document._graphql_deprecated({{ deprecated }}),
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
          unions = [] of TypeNode
          enums = [] of TypeNode
          scalars = [::GraphQL::Scalars::String, ::GraphQL::Scalars::Boolean, ::GraphQL::Scalars::Float, ::GraphQL::Scalars::Int, ::GraphQL::Scalars::ID] of TypeNode

          (0..1000).each do |i|
            obj = objects[i]
            if obj
              vars = obj.instance_vars.select(&.annotation(::GraphQL::Field))
              obj.ancestors.each do |ancestor|
                ancestor.instance_vars.select(&.annotation(::GraphQL::Field)).each do |var|
                  vars << var
                end
              end

              vars.select(&.annotation(::GraphQL::Field)).each do |prop|
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
                    if inner_type.resolve.annotation(::GraphQL::Object) && !objects.includes?(inner_type.resolve) && !(inner_type.resolve < ::GraphQL::Context)
                      objects << inner_type.resolve
                    end
                    if inner_type.resolve.annotation(::GraphQL::Enum) && !enums.includes?(inner_type.resolve)
                      enums << inner_type.resolve
                    end
                  end
                end
              end

              methods = obj.methods.select(&.annotation(::GraphQL::Field))
              obj.ancestors.each do |ancestor|
                ancestor.methods.select(&.annotation(::GraphQL::Field)).each do |method|
                  methods << method
                end
              end

              methods.each do |method|
                if method.return_type.is_a?(Nop) && !obj.annotation(::GraphQL::InputObject)
                  raise "GraphQL: #{obj.name.id}##{method.name.id} must have a return type"
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

                if obj.annotation(::GraphQL::Object) || obj.annotation(::GraphQL::Interface)
                  method.return_type.types.each do |type|
                    # the type itself, list element types, and the members
                    # of unions in either position
                    candidates = [] of TypeNode
                    type.resolve.union_types.each { |u| candidates << u }
                    if type.resolve < Array || type.resolve < Channel
                      type.resolve.type_vars.each do |inner_type|
                        inner_type.resolve.union_types.each { |u| candidates << u }
                        if inner_type.resolve < Array
                          inner_type.resolve.type_vars.each do |inner_inner|
                            inner_inner.resolve.union_types.each { |u| candidates << u }
                          end
                        end
                      end
                    end

                    # list elements of an abstract class are virtual types,
                    # which carry no annotations; resolve them by name
                    candidates = candidates.map { |c| parse_type(c.name.stringify).resolve }

                    candidates.each do |candidate|
                      if (candidate.annotation(::GraphQL::Object) || candidate.annotation(::GraphQL::InputObject) || candidate.annotation(::GraphQL::Interface)) && !objects.includes?(candidate) && !(candidate < ::GraphQL::Context)
                        objects << candidate
                      end

                      if candidate.annotation(::GraphQL::Union) && !unions.includes?(candidate)
                        unions << candidate
                      end

                      if candidate.annotation(::GraphQL::Interface) || candidate.annotation(::GraphQL::Union)
                        members = candidate.all_subclasses
                        if candidate.module?
                          candidate.includers.each do |includer|
                            members << includer
                            includer.all_subclasses.each { |sub| members << sub }
                          end
                        end
                        members.each do |member|
                          objects << member if member.annotation(::GraphQL::Object) && !objects.includes?(member)
                        end
                      end

                      if candidate.annotation(::GraphQL::Enum) && !enums.includes?(candidate)
                        enums << candidate
                      end

                      if candidate.annotation(::GraphQL::Scalar) && !scalars.includes?(candidate)
                        scalars << candidate
                      end
                    end
                  end
                end
              end

              # an object's interfaces, and their other implementations,
              # belong in the schema even when nothing returns them directly
              if obj.annotation(::GraphQL::Object)
                obj.ancestors.each do |ancestor|
                  if ancestor.annotation(::GraphQL::Interface) && !objects.includes?(ancestor)
                    objects << ancestor
                    members = ancestor.all_subclasses
                    if ancestor.module?
                      ancestor.includers.each do |includer|
                        members << includer
                        includer.all_subclasses.each { |sub| members << sub }
                      end
                    end
                    members.each do |member|
                      objects << member if member.annotation(::GraphQL::Object) && !objects.includes?(member)
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

          {%
            vars = object.instance_vars.select(&.annotation(::GraphQL::Field))
            object.ancestors.each do |ancestor|
              ancestor.instance_vars.select(&.annotation(::GraphQL::Field)).each do |var|
                vars << var
              end
            end
          %}

          {% for var in vars %}
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

          {%
            methods = object.methods.select(&.annotation(::GraphQL::Field))
            object.ancestors.each do |ancestor|
              ancestor.methods.select(&.annotation(::GraphQL::Field)).each do |method|
                methods << method
              end
            end
            # an override and the method it overrides describe one field
            seen = [] of String
            methods = methods.select do |m|
              n = m.annotation(::GraphQL::Field)["name"] || m.name.id.stringify.camelcase(lower: true)
              seen.includes?(n) ? false : (seen << n; true)
            end
          %}

          {% for method in methods %}
            %input_values = [] of ::GraphQL::Language::InputValueDefinition
            {% for arg in method.args %}
              {% unless arg.restriction.resolve <= ::GraphQL::Context %}
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
                  {{ ann_arg && ann_arg["deprecated"] || nil }},
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
            {% interface_names = object.ancestors.select(&.annotation(::GraphQL::Interface)).map { |a| a.annotation(::GraphQL::Interface)["name"] || a.name.split("::").last } %}
            %definitions << ::GraphQL::Language::ObjectTypeDefinition.new(
              name: {{ object.annotation(::GraphQL::Object)["name"] || object.name.split("::").last }},
              fields: %fields.sort{|a, b| a.name <=> b.name },
              interfaces: {{ interface_names.empty? ? "[] of String".id : interface_names }},
              directives: [] of ::GraphQL::Language::Directive,
              description: {{ object.annotation(::GraphQL::Object)["description"] }},
            )
          {% elsif object.annotation(::GraphQL::Interface) %}
            %definitions << ::GraphQL::Language::InterfaceTypeDefinition.new(
              name: {{ object.annotation(::GraphQL::Interface)["name"] || object.name.split("::").last }},
              fields: %fields.sort{|a, b| a.name <=> b.name },
              directives: [] of ::GraphQL::Language::Directive,
              description: {{ object.annotation(::GraphQL::Interface)["description"] }},
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

        {% for union in unions %}
          {%
            members = union.all_subclasses
            if union.module?
              union.includers.each do |includer|
                members << includer
                includer.all_subclasses.each { |sub| members << sub }
              end
            end
            member_names = members.select(&.annotation(::GraphQL::Object)).map { |m| m.annotation(::GraphQL::Object)["name"] || m.name.split("::").last }
            raise "GraphQL: union #{union.name} has no member types" if member_names.empty?
          %}
          %definitions << ::GraphQL::Language::UnionTypeDefinition.new(
            name: {{ union.annotation(::GraphQL::Union)["name"] || union.name.split("::").last }},
            description: {{ union.annotation(::GraphQL::Union)["description"] }},
            types: ({{ member_names }}.sort.map { |n| ::GraphQL::Language::TypeName.new(name: n) }),
            directives: [] of ::GraphQL::Language::Directive,
          )
        {% end %}

        {% for e_num in enums %}
          {% ann_values = e_num.annotation(::GraphQL::Enum)["values"] %}
          %definitions << ::GraphQL::Language::EnumTypeDefinition.new(
            name: {{ e_num.annotation(::GraphQL::Enum)["name"] || e_num.name.split("::").last }},
            description: {{ e_num.annotation(::GraphQL::Enum)["description"] }},
            fvalues: ([
              {% for constant in e_num.resolve.constants %}
              {% ann_value = ann_values && ann_values[constant] %}
              ::GraphQL::Language::EnumValueDefinition.new(
                name: {{ constant.stringify }},
                directives: ::GraphQL::Document._graphql_deprecated({{ ann_value && ann_value["deprecated"] || nil }}),
                selection: nil,
                description: {{ ann_value && ann_value["description"] || nil }},
              ),
              {% end %}
          ] of ::GraphQL::Language::EnumValueDefinition).sort {|a, b| a.name <=> b.name },
            directives: [] of ::GraphQL::Language::Directive,
          )
        {% end %}

        {% for scalar in scalars %}
          %scalar_directives = [] of ::GraphQL::Language::Directive
          {% if url = scalar.annotation(::GraphQL::Scalar)["specified_by_url"] %}
            %scalar_directives << ::GraphQL::Language::Directive.new(
              name: "specifiedBy",
              arguments: [::GraphQL::Language::Argument.new("url", {{ url }})],
            )
          {% end %}
          %definitions << ::GraphQL::Language::ScalarTypeDefinition.new(
            name: {{ scalar.annotation(::GraphQL::Scalar)["name"] || scalar.name.split("::").last }},
            description: {{ scalar.annotation(::GraphQL::Scalar)["description"] }},
            directives: %scalar_directives
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
