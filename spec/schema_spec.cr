require "./spec_helper"

describe GraphQL::Schema do
  it "Resolves human by id" do
    GraphQL::Schema.new(StarWars::Query.new).execute(%(
      {
        luke: human(id: "1000") {
          name
        }
      }
    )).should eq (
      {
        "data" => {
          "luke" => {
            "name" => "Luke Skywalker",
          },
        },
      }
    ).to_json
  end

  it "Resolves fragments" do
    GraphQL::Schema.new(StarWars::Query.new).execute(%(
      query UseFragment {
        luke: human(id: "1000") {
          ...HumanFragment
        }
        leia: human(id: "1003") {
          ...HumanFragment
        }
      }
      fragment HumanFragment on Human {
        name
        homePlanet
      }
    )).should eq (
      {
        "data" => {
          "luke" => {
            "name"       => "Luke Skywalker",
            "homePlanet" => "Tatooine",
          },
          "leia" => {
            "name"       => "Leia Organa",
            "homePlanet" => "Alderaan",
          },
        },
      }
    ).to_json
  end

  it "Resolves inline fragments" do
    GraphQL::Schema.new(StarWars::Query.new).execute(%(
      query UseFragment {
        luke: human(id: "1000") {
          ... on Human {
            name
            homePlanet
          }
        }
      }
    )).should eq (
      {
        "data" => {
          "luke" => {
            "name"       => "Luke Skywalker",
            "homePlanet" => "Tatooine",
          },
        },
      }
    ).to_json
  end

  it "Generates correct schema" do
    GraphQL::Schema.new(StarWars::Query.new).document.to_s.should eq %(
"A Boolean Value"
scalar Boolean

type Droid {
  primaryFunction: String!
}

"A Floating Point Number"
scalar Float

type Human {
  homePlanet: String
}

"An ID"
scalar ID

"An Integer Number"
scalar Int

type Query {
  droid(id: String!): Droid
  hero(episode: Episode!): Human!
  human(id: String!): Human
  humans: [Human!]!
}

"A String Value"
scalar String

type __Directive {
  args: [__InputValue!]!
  description: String
  locations: [String!]!
  name: String!
}

type __EnumValue {
  deprecationReason: String
  description: String
  isDeprecated: Boolean!
  name: String!
}

type __Field {
  args: [__InputValue!]!
  deprecationReason: String
  description: String
  isDeprecated: Boolean!
  name: String!
  type: __Type!
}

type __InputValue {
  defaultValue: String
  description: String
  name: String!
  type: __Type!
}

type __Schema {
  directives: [__Directive!]!
  mutationType: __Type
  queryType: __Type!
  subscriptionType: __Type
  types: [__Type!]!
}

type __Type {
  description: String
  enumValues(includeDeprecated: Boolean): [__EnumValue!]
  fields(includeDeprecated: Boolean): [__Field!]
  inputFields: [__InputValue!]
  interfaces: [__Type!]
  kind: __TypeKind!
  name: String
  ofType: __Type
  possibleTypes: [__Type!]
}

enum __TypeKind {
  ENUM
  INPUT_OBJECT
  INTERFACE
  LIST
  NON_NULL
  OBJECT
  SCALAR
  UNION
}
    ).strip
  end
end
