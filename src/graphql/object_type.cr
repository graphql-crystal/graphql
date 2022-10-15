require "./language"
require "./scalar_type"
require "./internal/convert_value"

module GraphQL::ObjectType
  macro included
    macro finished
      {% verbatim do %}
      {% verbatim do %}

      # :nodoc:
      def _graphql_type : String
        {{ @type.annotation(::GraphQL::Object)["name"] || @type.name.split("::").last }}
      end

      # :nodoc:
      private macro _graphql_serialize(val)
        case val = {{ val }}
        when ::GraphQL::ObjectType
          json.object do
            val._graphql_resolve(context, field.selections, json).each do |error|
              errors << error.with_path(path)
            end
          end
        when Array
          json.array do
            val.each_with_index do |v, i|
              case v
              when ::GraphQL::ObjectType
                json.object do
                  v._graphql_resolve(context, field.selections, json).each do |error|
                    errors << error.with_path(i).with_path(path)
                  end
                end
              when ::Enum
                json.scalar(v.to_s)
              else
                v.to_json(json)
              end
            end
          end
        when ::Enum
          json.string val
        when Bool, String, Int32, Float64, Nil, ::GraphQL::ScalarType
          val.to_json(json)
        else
          raise ::GraphQL::TypeError.new("no serialization found for field #{path} on #{_graphql_type}")
        end
      end

      # :nodoc:
      def _graphql_skip?(selection : ::GraphQL::Language::Field | ::GraphQL::Language::FragmentSpread | ::GraphQL::Language::InlineFragment)
        if skip = selection.directives.find { |d| d.name == "skip" }
          if arg = skip.arguments.find { |a| a.name == "if" }
            return true if arg.value.as(Bool)
          end
        end

        if inc = selection.directives.find { |d| d.name == "include" }
          if arg = inc.arguments.find { |a| a.name == "if" }
            return true if !arg.value.as(Bool)
          end
        end

        false
      end

      # :nodoc:
      def _graphql_resolve(context, selections : Array(::GraphQL::Language::Selection), json : JSON::Builder) : Array(::GraphQL::Error)
        error_channel = Channel(::GraphQL::Error).new
        json_fragment_channel = Channel({String, String}).new
        errors = Array(::GraphQL::Error).new

        spawn do
          while error = error_channel.receive?
            errors << error
          end
        end

        unskipped_selections = selections.reject do |selection|
          case selection
          when ::GraphQL::Language::Field, ::GraphQL::Language::FragmentSpread, ::GraphQL::Language::InlineFragment
            _graphql_skip?(selection)
          else
            false
          end
        end

        unskipped_selections.each do |selection|
          case selection
          when ::GraphQL::Language::Field
            spawn do
              path = selection._alias || selection.name

              fragment = String.build do |fragment|
                fragment_builder = JSON::Builder.new(fragment)
                fragment_builder.document do
                  _graphql_resolve(context, selection, fragment_builder).each do |error|
                    error_channel.send error
                  end
                end
              rescue e
                if message = context.handle_exception(e)
                  error_channel.send ::GraphQL::Error.new(message, path)
                end
              end

              json_fragment_channel.send({path, fragment})
            end
          when ::GraphQL::Language::FragmentSpread
            begin
              _graphql_resolve(context, selection, json).each { |error| error_channel.send error }
            rescue e
              if message = context.handle_exception(e)
                error_channel.send ::GraphQL::Error.new(message, selection.name)
              end
            end
          when ::GraphQL::Language::InlineFragment
            _graphql_resolve(context, selection.selections, json).each { |error| error_channel.send error }
          else
            # this never happens, only required due to Selection being turned into ASTNode
            # https://crystal-lang.org/reference/1.3/syntax_and_semantics/virtual_and_abstract_types.html
            raise ::GraphQL::TypeError.new("invalid selection type")
          end
        end

        json_fragments = [] of {String, String}

        unskipped_fields = unskipped_selections.each.select { |s| s.is_a?(::GraphQL::Language::Field) }.map(&.as(::GraphQL::Language::Field)).to_a

        unskipped_fields.size.times do
          json_fragments << json_fragment_channel.receive
        end

        error_channel.close

        json_fragments.sort_by! do |path, _|
          unskipped_fields.index! do |selection|
            selection_path = selection._alias || selection.name
            path == selection_path
          end
        end


        json_fragments.each do |path, fragment|
          next if fragment.empty?
          json.field(path) { json.raw fragment }
        end

        errors
      end

      # :nodoc:
      def _graphql_resolve(context, fragment : ::GraphQL::Language::FragmentSpread, json : JSON::Builder) : Array(::GraphQL::Error)
        errors = [] of ::GraphQL::Error
        f = context.fragments.find{ |f| f.name == fragment.name}
        if f.nil?
          errors << ::GraphQL::Error.new("no fragment #{fragment.name}", fragment.name)
        else
          errors.concat _graphql_resolve(context, f.selections, json)
        end
        errors
      end

      # :nodoc:
      def _graphql_resolve(context, field : ::GraphQL::Language::Field, json : JSON::Builder) : Array(::GraphQL::Error)
        {% begin %}
        errors = [] of ::GraphQL::Error
        path = field._alias || field.name

        case field.name
        {% for var in @type.instance_vars.select(&.annotation(::GraphQL::Field)) %}
        when {{ var.annotation(::GraphQL::Field)["name"] || var.name.id.stringify.camelcase(lower: true) }}
          _graphql_serialize self.{{var.name.id}}
        {% end %}
        {% methods = @type.methods.select(&.annotation(::GraphQL::Field)) %}
        {% for ancestor in @type.ancestors %}
          {% for method in ancestor.methods.select(&.annotation(::GraphQL::Field)) %}
            {% methods << method %}
          {% end %}
        {% end %}
        {% for method in methods %}
        when {{ method.annotation(::GraphQL::Field)["name"] || method.name.id.stringify.camelcase(lower: true) }}
          _graphql_serialize self.{{method.name.id}}(
            {% for arg in method.args %}
            {% raise "GraphQL: #{@type.name}##{method.name} args must have type restriction" if arg.restriction.is_a? Nop %}
            {% type = arg.restriction.resolve.union_types.find { |t| t != Nil }.resolve %}
            {{ arg.name }}: begin
              if context.is_a? {{arg.restriction.id}}
                context
              elsif fa = field.arguments.find {|a| a.name == {{ arg.name.id.stringify.camelcase(lower: true) }}}
                GraphQL::Internal.convert_value {{ type }}, fa.value, {{ arg.name.id.camelcase(lower: true) }}
              else
                {% if !arg.default_value.is_a?(Nop) %}
                  {{ arg.default_value }}.as({{arg.restriction.id}})
                {% elsif arg.restriction.resolve.nilable? %}
                  nil
                {% else %}
                  raise ::GraphQL::TypeError.new("missing required argument {{ arg.name.id.camelcase(lower: true) }}")
                {% end %}
              end
            end,
            {% end %}
          )
        {% end %}
        when "__typename"
          json.string _graphql_type
        {% if @type < ::GraphQL::QueryType %}
        when "__schema"
          json.object do
            introspection = ::GraphQL::Introspection::Schema.new(context.document.not_nil!, _graphql_type, context.mutation_type)
            introspection._graphql_resolve(context, field.selections, json).each do |error|
              errors << error.with_path(path)
            end
          end
        {% end %}
        else
          raise ::GraphQL::TypeError.new("field is not defined")
        end
        errors

        {% end %}
      end

      {% end %}
      {% end %}
    end
  end
end

module GraphQL
  abstract class BaseObject
    macro inherited
      include GraphQL::ObjectType
    end
  end
end
