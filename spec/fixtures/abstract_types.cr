module AbstractTypes
  @[GraphQL::Interface(description: "A character in the saga")]
  abstract class Character < GraphQL::BaseObject
    @[GraphQL::Field]
    abstract def name : String

    @[GraphQL::Field]
    def greeting : String
      "I am #{name}"
    end
  end

  @[GraphQL::Union]
  module SearchResult
  end

  @[GraphQL::Object]
  class Human < Character
    include SearchResult

    def initialize(@name : String, @home_planet : String)
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    @[GraphQL::Field]
    def home_planet : String
      @home_planet
    end
  end

  @[GraphQL::Object]
  class Droid < Character
    def initialize(@name : String, @primary_function : String)
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    @[GraphQL::Field]
    def primary_function : String
      @primary_function
    end
  end

  @[GraphQL::Object]
  class Starship < GraphQL::BaseObject
    include SearchResult

    def initialize(@length : Float64)
    end

    @[GraphQL::Field]
    def length : Float64
      @length
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def hero : Character
      Human.new("Luke", "Tatooine")
    end

    @[GraphQL::Field]
    def characters : Array(Character)
      [Human.new("Luke", "Tatooine"), Droid.new("R2-D2", "astromech")] of Character
    end

    @[GraphQL::Field]
    def missing : Character?
      nil
    end

    @[GraphQL::Field]
    def search : Array(SearchResult)
      [Human.new("Leia", "Alderaan"), Starship.new(34.37)] of SearchResult
    end
  end
end
