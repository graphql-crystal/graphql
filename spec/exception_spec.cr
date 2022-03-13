require "./spec_helper"

module ExceptionFixture
  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def err : String?
      raise "foo"
    end
  end

  class Context < GraphQL::Context
    def handle_exception(ex : Exception) : String?
      "handled"
    end
  end
end

describe Exception do
  it "handles exception" do
    GraphQL::Schema.new(ExceptionFixture::Query.new).execute(
      %(
        {
          err
        }
      ),
      context: ExceptionFixture::Context.new
    ).should eq (
      {
        "data"   => {} of Nil => Nil,
        "errors" => [
          {
            "message" => "handled",
            "path"    => ["err"],
          },
        ],
      }
    ).to_json
  end
end
