require "./spec_helper"

module ArrayFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
   @[GraphQL::Field]
   def nested(arr : Array(Array(Array(String)))) : Array(Array(Array(String)))
     arr
   end
  end
end

describe GraphQL do
  it "resolves nested arrays" do
   GraphQL::Schema.new(ArrayFixture::Query.new).execute(
     %(
       {
         nested(arr: [[["foo"]]])
       }
     )
   ).should eq (
     {
       "data" => {
         "nested" => [[["foo"]]],
      }
     }
   ).to_json
  end
end
