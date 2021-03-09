module GraphQL
  module Language
    abstract class ASTNode
      macro values(args)
        property {{args.map { |k, v| "#{k} : #{v}" }.join(",").id}}

        def_equals_and_hash {{args.keys}}

        def initialize({{args.keys.join(",").id}}, **rest)
          {%
            assignments = args.map do |k, v|
              if v.is_a?(Generic) && v.name.id == "Array"
                type = v.type_vars.first.id
                "@#{k.id} = #{k.id}.map(&.as(#{type}))"
              else
                "@#{k.id} = #{k.id}"
              end
            end
          %}

          {{assignments.join("\n").id}}

          super(**rest)
        end
      end

      def children
        [] of ASTNode
      end

      def visit(block : ASTNode -> _)
        children.each do |c|
          case val = c
          when Array
            val.each(&.visit(block))
          when nil
          else
            val.visit(block)
          end
        end

        block.call(self)
      end
    end # ASTNode
  end
end
