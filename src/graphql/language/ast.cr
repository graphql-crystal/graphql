module GraphQL
  module Language
    abstract class ASTNode
      # Where the node starts in the query source, set by the parser on the
      # nodes errors refer to. Line and column are derived on demand, since
      # almost no node ever appears in an error.
      @source : String?
      @start : Int32?
      @line : Int32?
      @column : Int32?

      def initialize(@source : String? = nil, @start : Int32? = nil)
      end

      # 1-based line of the node in the query, if known.
      def line : Int32?
        locate
        @line
      end

      # 1-based column of the node in the query, if known.
      def column : Int32?
        locate
        @column
      end

      private def locate : Nil
        return if @line
        return unless (source = @source) && (start = @start)
        line = 1
        line_start = 0
        source.each_char_with_index do |char, index|
          break if index >= start
          if char == '\n'
            line += 1
            line_start = index + 1
          end
        end
        @line = line
        @column = start - line_start + 1
      end

      macro values(args)
        property {{ args.map { |k, v| "#{k} : #{v}" }.join(",").id }}

        def_equals_and_hash {{ args.keys }}

        def initialize({{ args.keys.join(",").id }}, **rest)
          {%
            assignments = args.map do |k, v|
              if v.is_a?(Generic) && v.name.id == "Array"
                # widen e.g. Array(Field) to Array(Selection); an array that
                # already has the declared type is kept as is
                type = v.type_vars.first.id
                "@#{k.id} = #{k.id}.is_a?(#{v.id}) ? #{k.id} : #{k.id}.map(&.as(#{type}))"
              else
                "@#{k.id} = #{k.id}"
              end
            end
          %}

          {{ assignments.join("\n").id }}

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
