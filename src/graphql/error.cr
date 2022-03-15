require "json"

module GraphQL
  class Error
    include JSON::Serializable

    @[JSON::Field]
    property message : String

    @[JSON::Field]
    property path : Array(String | Int32)

    def initialize(@message, path : String)
      @path = [path] of String | Int32
    end

    def initialize(@message, @path : Array(String | Int32))
    end

    def with_path(path : String | Int32)
      @path.unshift path
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
