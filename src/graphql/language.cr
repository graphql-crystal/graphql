require "./language/lexer"
require "./language/nodes"
require "./language/parser"
require "./language/generation"

module GraphQL::Language
  # Nesting depth of selection sets, lists and input objects beyond which
  # `parse` raises. See `Context#max_depth`.
  DEFAULT_MAX_DEPTH = 100

  # Parse a query string and return the Document
  def self.parse(query_string : String, max_depth : Int32 = DEFAULT_MAX_DEPTH) : GraphQL::Language::Document
    GraphQL::Language::Parser.new(GraphQL::Language::Lexer.new).parse(query_string, max_depth)
  end
end
