require "./spec_helper"

describe GraphQL::Schema do
  it "QueryFixture generates correct schema" do
    got = GraphQL::Schema.new(QueryFixture::Query.new).document.to_s.strip
    expected = {{ read_file("spec/fixtures/query.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

  it "MutationFixture generates correct schema" do
    got = GraphQL::Schema.new(EmptyQueryFixture::Query.new, MutationFixture::Mutation.new).document.to_s.strip
    expected = {{ read_file("spec/fixtures/mutation.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end

  it "StarWars generates correct schema" do
    got = GraphQL::Schema.new(StarWars::Query.new).document.to_s.strip
    expected = {{ read_file("spec/fixtures/star_wars.graphql") }}.strip
    puts "\n====================\n#{got}\n====================" if got != expected
    got.should eq expected
  end
end
