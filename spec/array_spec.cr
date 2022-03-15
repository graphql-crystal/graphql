require "./spec_helper"

module ArrayFixture
  # @[GraphQL::Object]
  # class Query < GraphQL::BaseQuery
  #  @[GraphQL::Field]
  #  def nested(arr : Array(Array(Array(String)))) : Array(Array(Array(String)))
  #    arr
  #  end
  # end
end

describe Array do
  # TODO fix document macro
  # it "supports nested arrays" do
  #  GraphQL::Schema.new(ArrayFixture::Query.new).execute(
  #    %(
  #      {
  #        nested(arr: [[["foo"]]])
  #      }
  #    ),
  #    context: ExceptionFixture::Context.new
  #  ).should eq (
  #    {
  #      "data" => {} of Nil => Nil,
  #    }
  #  ).to_json
  # end
end
