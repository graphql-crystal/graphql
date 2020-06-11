require "./spec_helper"

describe GraphQL::Introspection do
  it "returns expected introspection result" do
    got = GraphQL::Schema.new(QueryFixture::Query.new).execute(GraphQL::INTROSPECTION_QUERY)
    expected = JSON.parse({{ read_file "spec/fixtures/query_introspection.json" }}).to_json
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

  it "resolves nested input object with various value types" do
    GraphQL::Schema.new(QueryFixture::Query.new).execute(%(
      {
        echoNestedInputObject(nestedInputObject: {
          nestedInputObject: {
            nestedInputObject: {
              nestedInputObject: {
                str: "ok"
              }
            },
            float: 11.111111
          },
          int: 1,
          float: 1
        }) {
          nestedObject {
            nestedObject {
              nestedObject {
                str
              }
            }
            float
          }
          int
          float
        }
      }
    )).should eq (
      {
        "data" => {
          "echoNestedInputObject" => {
            "nestedObject" => {
              "nestedObject" => {
                "nestedObject" => {
                  "str" => "ok",
                },
              },
              "float" => 11.111111,
            },
            "int"   => 1,
            "float" => 1.0,
          },
        },
      }
    ).to_json
  end
end
