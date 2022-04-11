require "./spec_helper"

describe GraphQL::Language do
  it "parses and serializes query schema" do
    schema = {{ read_file("spec/fixtures/query.graphql") }}.strip
    schema.should eq GraphQL::Language.parse(schema).to_s
    1.should eq 2
  end

  it "parses and serializes mutation schema" do
    schema = {{ read_file("spec/fixtures/mutation.graphql") }}.strip
    schema.should eq GraphQL::Language.parse(schema).to_s
    1.should eq 2
  end
end
