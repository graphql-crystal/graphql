require "./spec_helper"

module BigIntFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def add(bi : GraphQL::Scalars::BigInt, i : Int32) : GraphQL::Scalars::BigInt
      GraphQL::Scalars::BigInt.new(bi.value + i)
    end
  end
end

describe GraphQL::Scalars::BigInt do
  it "echos bigint" do
    GraphQL::Schema.new(BigIntFixture::Query.new).execute(
      %(
        {
          add(bi: "12345678901234567890", i: 1)
        }
      )
    ).should eq (
      {
        "data" => {
          "add" => "12345678901234567891",
        },
      }
    ).to_json
  end
end
