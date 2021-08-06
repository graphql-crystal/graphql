require "./spec_helper"

describe StarWars::Query do
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

  it "Allows passing an io to render json to it" do
    result = String.build do |io|
      GraphQL::Schema.new(StarWars::Query.new).execute(
        io,
        %(
            {
              luke: human(id: "1000") {
                name
              }
            }
        )
      )
    end

    result.should eq (
      {
        "data" => {
          "luke" => {
            "name" => "Luke Skywalker",
          },
        },
      }
    ).to_json
  end
end
