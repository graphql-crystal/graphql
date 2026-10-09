require "json"

module GraphQL
  class Error
    include JSON::Serializable

    record Location, line : Int32, column : Int32 do
      include JSON::Serializable
    end

    @[JSON::Field]
    property message : String

    # Where in the query the error originated. Absent for errors that are
    # not tied to a position, such as a missing variable.
    @[JSON::Field]
    property locations : Array(Location)?

    # Response path of the field that failed. Absent for request errors.
    @[JSON::Field]
    property path : Array(String | Int32)?

    def initialize(@message, path : String, node : Language::ASTNode? = nil)
      @path = [path] of String | Int32
      @locations = Error.locations_of(node)
    end

    def initialize(@message, @path : Array(String | Int32)? = nil, node : Language::ASTNode? = nil)
      @locations = Error.locations_of(node)
    end

    # :nodoc:
    def self.locations_of(node : Language::ASTNode?) : Array(Location)?
      return unless node
      line, column = node.line, node.column
      return unless line && column
      [Location.new(line, column)]
    end

    def with_path(path : String | Int32)
      (@path ||= [] of String | Int32).unshift path
      self
    end
  end

  abstract class Exception < ::Exception
  end

  class TypeError < Exception
  end

  class ParserError < Exception
  end
end
