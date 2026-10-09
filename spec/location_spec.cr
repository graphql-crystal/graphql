require "./spec_helper"

module LocationFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def ok : String
      "ok"
    end

    @[GraphQL::Field]
    def boom : String?
      raise "boom"
    end
  end
end

describe "error locations" do
  schema = GraphQL::Schema.new(LocationFixture::Query.new)

  it "points at the failing field, counting lines and columns from 1" do
    schema.execute("{\n  ok\n    aliased: boom\n}").should eq (
      {
        "data"   => {"ok" => "ok", "aliased" => nil},
        "errors" => [{"message" => "boom", "locations" => [{"line" => 3, "column" => 5}], "path" => ["aliased"]}],
      }
    ).to_json
  end

  it "points at the fragment spread for fragment errors" do
    schema.execute("{\n  ok\n  ...Missing\n}").should eq (
      {
        "data"   => {"ok" => "ok"},
        "errors" => [{"message" => "no fragment Missing", "locations" => [{"line" => 3, "column" => 3}], "path" => ["Missing"]}],
      }
    ).to_json
  end

  it "points at the field inside a fragment, not the spread" do
    schema.execute("{\n  ...F\n}\nfragment F on Query {\n  boom\n}").should eq (
      {
        "data"   => {"boom" => nil},
        "errors" => [{"message" => "boom", "locations" => [{"line" => 5, "column" => 3}], "path" => ["boom"]}],
      }
    ).to_json
  end

  it "omits locations and path on request errors" do
    schema.execute("query ($x: Int!) { ok }").should eq (
      {"errors" => [{"message" => "missing required variable x"}]}
    ).to_json
  end
end
