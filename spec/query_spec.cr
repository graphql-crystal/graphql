require "./spec_helper"

describe GraphQL::Introspection do
  it "Returns expected introspection result" do
    GraphQL::Schema.new(QueryFixture::Query.new).execute(GraphQL::INTROSPECTION_QUERY).should eq (
      JSON.parse({{ read_file "spec/fixtures/query_introspection.json" }}).to_json
    )
  end
end
