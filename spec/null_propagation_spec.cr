require "./spec_helper"

module NullPropagationFixture
  @[GraphQL::Object]
  class Leaf < GraphQL::BaseObject
    @[GraphQL::Field]
    def ok : String
      "ok"
    end

    @[GraphQL::Field]
    def nullable : String?
      raise "nullable failed"
    end

    @[GraphQL::Field]
    def required : String
      raise "required failed"
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def leaf : Leaf?
      Leaf.new
    end

    @[GraphQL::Field]
    def required_leaf : Leaf
      Leaf.new
    end

    @[GraphQL::Field]
    def leaves : Array(Leaf)?
      [Leaf.new, Leaf.new]
    end

    @[GraphQL::Field]
    def nullable_leaves : Array(Leaf?)?
      [Leaf.new, Leaf.new] of Leaf?
    end

    @[GraphQL::Field]
    def required_leaves : Array(Leaf)
      [Leaf.new]
    end

    @[GraphQL::Field]
    def ok : String
      "ok"
    end
  end
end

describe "null propagation" do
  schema = GraphQL::Schema.new(NullPropagationFixture::Query.new)

  it "renders a failed nullable field as null" do
    schema.execute(%({ ok leaf { ok nullable } })).should eq (
      {
        "data"   => {"ok" => "ok", "leaf" => {"ok" => "ok", "nullable" => nil}},
        "errors" => [{"message" => "nullable failed", "locations" => [{"line" => 1, "column" => 16}], "path" => ["leaf", "nullable"]}],
      }
    ).to_json
  end

  it "nulls the nearest nullable ancestor of a failed non-null field" do
    schema.execute(%({ ok leaf { ok required } })).should eq (
      {
        "data"   => {"ok" => "ok", "leaf" => nil},
        "errors" => [{"message" => "required failed", "locations" => [{"line" => 1, "column" => 16}], "path" => ["leaf", "required"]}],
      }
    ).to_json
  end

  it "nulls data when the failure reaches a non-null root field" do
    schema.execute(%({ ok requiredLeaf { ok required } })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "required failed", "locations" => [{"line" => 1, "column" => 24}], "path" => ["requiredLeaf", "required"]}],
      }
    ).to_json
  end

  it "keeps sibling errors when propagating" do
    schema.execute(%({ leaf { nullable required } })).should eq (
      {
        "data"   => {"leaf" => nil},
        "errors" => [
          {"message" => "nullable failed", "locations" => [{"line" => 1, "column" => 10}], "path" => ["leaf", "nullable"]},
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 19}], "path" => ["leaf", "required"]},
        ],
      }
    ).to_json
  end

  it "nulls a list whose non-null element failed" do
    schema.execute(%({ ok leaves { required } })).should eq (
      {
        "data"   => {"ok" => "ok", "leaves" => nil},
        "errors" => [
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 15}], "path" => ["leaves", 0, "required"]},
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 15}], "path" => ["leaves", 1, "required"]},
        ],
      }
    ).to_json
  end

  it "nulls only the element when elements are nullable" do
    schema.execute(%({ nullableLeaves { required } })).should eq (
      {
        "data"   => {"nullableLeaves" => [nil, nil]},
        "errors" => [
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 20}], "path" => ["nullableLeaves", 0, "required"]},
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 20}], "path" => ["nullableLeaves", 1, "required"]},
        ],
      }
    ).to_json
  end

  it "propagates through a non-null list to data" do
    schema.execute(%({ ok requiredLeaves { required } })).should eq (
      {
        "data"   => nil,
        "errors" => [{"message" => "required failed", "locations" => [{"line" => 1, "column" => 23}], "path" => ["requiredLeaves", 0, "required"]}],
      }
    ).to_json
  end

  it "behaves the same with concurrent resolution" do
    ctx = GraphQL::Context.new
    ctx.max_concurrency = 8
    schema.execute(%({ ok leaf { ok required } leaves { ok nullable } }), context: ctx).should eq (
      {
        "data" => {
          "ok"     => "ok",
          "leaf"   => nil,
          "leaves" => [{"ok" => "ok", "nullable" => nil}, {"ok" => "ok", "nullable" => nil}],
        },
        "errors" => [
          {"message" => "required failed", "locations" => [{"line" => 1, "column" => 16}], "path" => ["leaf", "required"]},
          {"message" => "nullable failed", "locations" => [{"line" => 1, "column" => 39}], "path" => ["leaves", 0, "nullable"]},
          {"message" => "nullable failed", "locations" => [{"line" => 1, "column" => 39}], "path" => ["leaves", 1, "nullable"]},
        ],
      }
    ).to_json
    ctx.in_flight.should eq 0
  end
end
