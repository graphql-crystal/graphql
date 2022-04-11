require "./spec_helper"

describe GraphQL::Language do
  it "parses and generates query schema" do
    schema = {{ read_file("spec/fixtures/query.graphql") }}.strip
    schema.should eq GraphQL::Language.parse(schema).to_s
  end

  it "parses and generates mutation schema" do
    schema = {{ read_file("spec/fixtures/mutation.graphql") }}.strip
    schema.should eq GraphQL::Language.parse(schema).to_s
  end

  it "parses block string with quote" do
    schema = %(
      """
      Description with quote "
      """
      scalar Foo
    )
    GraphQL::Language.parse(schema)
  end
end
