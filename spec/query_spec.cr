require "./spec_helper"

describe GraphQL::Introspection do
  it "returns expected introspection result" do
    got = GraphQL::Schema.new(QueryFixture::Query.new).execute(GraphQL::INTROSPECTION_QUERY)
    expected = JSON.parse({{ read_file "spec/fixtures/query_introspection.json" }}).to_json
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

  it "resolves nested input object with various value types" do
    GraphQL::Schema.new(QueryFixture::Query.new).execute(
      %(
        {
          echoNestedInputObject(nestedInputObject: {
            object: {
              object: {
                object: {
                  str: "ok",
                  array: [
                    {
                      str: $str,
                      int: $int,
                      float: $float,
                    }
                  ]
                }
              },
              float: 11.111111
            },
            int: 1,
            float: 1
          }) {
            object {
              object {
                object {
                  str
                  array {
                    str
                    int
                    float
                    id
                    strReverse
                  }
                }
              }
              float
            }
            int
            float
          }
        }
      ),
      {"str" => JSON::Any.new("foo"), "int" => JSON::Any.new(123_i64), "float" => JSON::Any.new(11_i64)} of String => JSON::Any
    ).should eq (
      {
        "data" => {
          "echoNestedInputObject" => {
            "object" => {
              "object" => {
                "object" => {
                  "str"   => "ok",
                  "array" => [
                    {
                      "str"        => "foo",
                      "int"        => 123,
                      "float"      => 11.0,
                      "id"         => "foo",
                      "strReverse" => "oof",
                    },
                  ],
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

  it "resolves record field" do
    GraphQL::Schema.new(QueryFixture::Query.new).execute(
      %(
        query {
          record(value: "myvalue") {
            value
          }
        }
      )
    ).should eq (
      {
        "data" => {
          "record" => {
            "value" => "myvalue",
          },
        },

      }
    ).to_json
  end

  it "fails for mutations" do
    GraphQL::Schema.new(QueryFixture::Query.new).execute(
      %(
        mutation {
          foobar(baz: "123")
        }
      )
    ).should eq (
      {
        "errors" => [
          {"message" => "mutation operations are not supported",
           "path"    => [] of Nil,
          },
        ],
      }
    ).to_json
  end
end
