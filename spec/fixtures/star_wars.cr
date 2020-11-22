module StarWars
  CHARACTERS = [
    Human.new(
      id: "1000",
      name: "Luke Skywalker",
      friends: ["1002", "1003", "2000", "2001"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
      home_planet: "Tatooine"
    ),
    Human.new(
      id: "1001",
      name: "Darth Vader",
      friends: ["1004"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
      home_planet: "Tatooine"
    ),
    Human.new(
      id: "1002",
      name: "Han Solo",
      friends: ["1000", "1003", "2001"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
    ),
    Human.new(
      id: "1003",
      name: "Leia Organa",
      friends: ["1000", "1002", "2000", "2001"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
      home_planet: "Alderaan",
    ),
    Human.new(
      id: "1004",
      name: "Wilhuff Tarkin",
      friends: ["1001"],
      appears_in: [Episode::IV],
    ),
    Droid.new(
      id: "2000",
      name: "C-3PO",
      friends: ["1000", "1002", "1003", "2001"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
      primary_function: "Protocol",
    ),
    Droid.new(
      id: "2001",
      name: "R2-D2",
      friends: ["1000", "1002", "1003"],
      appears_in: [Episode::IV, Episode::V, Episode::VI],
      primary_function: "Astromech",
    ),
  ] of Human | Droid

  @[GraphQL::Enum(description: "List of starwars episodes")]
  enum Episode
    IV
    V
    VI
  end

  @[GraphQL::Object]
  abstract class Character
    include GraphQL::ObjectType

    @id : String
    @name : String
    @friends : Array(String)
    @appears_in : Array(Episode)

    def initialize(@id, @name, @friends, @appears_in)
    end

    @[GraphQL::Field]
    def id : String
      @id
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    # @[GraphQL::Field]
    # def friends : Array(Character)
    #  @friends
    # end
  end

  @[GraphQL::Object]
  class Human < Character
    include GraphQL::ObjectType

    @home_planet : String?

    def initialize(@id, @name, @friends, @appears_in, @home_planet = nil)
    end

    @[GraphQL::Field]
    def home_planet : String?
      @home_planet
    end
  end

  @[GraphQL::Object]
  class Droid < Character
    include GraphQL::ObjectType

    @primary_function : String

    def initialize(@id, @name, @friends, @appears_in, @primary_function)
    end

    @[GraphQL::Field]
    def primary_function : String
      @primary_function
    end
  end

  @[GraphQL::Object]
  class Query
    include GraphQL::ObjectType
    include GraphQL::QueryType

    @[GraphQL::Field(description: "Get hero for episode", arguments: {
      episode: {description: "The episode"},
    })]
    def hero(episode : Episode) : Human
      humans.first
    end

    @[GraphQL::Field]
    def humans : Array(Human)
      humans = [] of Human
      CHARACTERS.select { |c| c.is_a?(Human) }.each { |h| humans << h.as(Human) }
      humans
    end

    @[GraphQL::Field]
    def human(id : String) : Human?
      CHARACTERS.find { |c| c.is_a?(Human) && c.id == id }.as(Human)
    end

    @[GraphQL::Field]
    def droid(id : String) : Droid?
      CHARACTERS.find { |c| c.is_a?(Droid) && c.id == id }.as(Droid)
    end
  end
end
