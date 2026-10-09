require "./parser_context"

class GraphQL::Language::Parser
  def initialize(lexer : Language::Lexer)
    @lexer = lexer
  end

  def parse(source : String, max_depth : Int32 = Language::DEFAULT_MAX_DEPTH) : Language::Document
    Language::ParserContext.new(source, @lexer, max_depth).parse
  end
end
