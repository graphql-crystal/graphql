require "json"

module GraphQL
  class Error
    JSON.mapping(
      message: String,
      path: Array(String | Int32),
    )

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
end
