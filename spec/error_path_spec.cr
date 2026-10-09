require "./spec_helper"

module ErrorPathFixture
  @[GraphQL::Object]
  class Item < GraphQL::BaseObject
    def initialize(@index : Int32)
    end

    @[GraphQL::Field]
    def index : Int32
      @index
    end

    @[GraphQL::Field]
    def boom : String?
      raise "boom #{@index}"
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def item : Item
      Item.new(0)
    end

    @[GraphQL::Field]
    def items : Array(Item)
      [Item.new(0), Item.new(1)]
    end

    @[GraphQL::Field]
    def nested : Array(Array(Item))
      [[Item.new(0)], [Item.new(1)]]
    end
  end
end

describe "error paths" do
  schema = GraphQL::Schema.new(ErrorPathFixture::Query.new)

  it "names the field and the alias" do
    schema.execute(%({ it: item { index boom } })).should eq (
      {
        "data"   => {"it" => {"index" => 0}},
        "errors" => [{"message" => "boom 0", "path" => ["it", "boom"]}],
      }
    ).to_json
  end

  it "includes the index of a list element once" do
    schema.execute(%({ items { index boom } })).should eq (
      {
        "data"   => {"items" => [{"index" => 0}, {"index" => 1}]},
        "errors" => [
          {"message" => "boom 0", "path" => ["items", 0, "boom"]},
          {"message" => "boom 1", "path" => ["items", 1, "boom"]},
        ],
      }
    ).to_json
  end

  it "includes every index of a nested list" do
    schema.execute(%({ nested { boom } })).should eq (
      {
        "data"   => {"nested" => [[{} of String => String], [{} of String => String]]},
        "errors" => [
          {"message" => "boom 0", "path" => ["nested", 0, 0, "boom"]},
          {"message" => "boom 1", "path" => ["nested", 1, 0, "boom"]},
        ],
      }
    ).to_json
  end
end
