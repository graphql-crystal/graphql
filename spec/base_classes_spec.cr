require "./spec_helper"

describe GraphQL::BaseObject do
  it "creates schema through inheritance class" do
    GraphQL::Schema.new(BaseClassesFixture::Query.new).execute(
      %(
        {
          result: helloWorld
        }
      )
    ).should eq (
      {
        "data" => {
          "result" => "hello world",
        },
      }
    ).to_json
  end
end
