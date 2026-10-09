require "./spec_helper"

module ConcurrencyApi
  # Tracks how many `value` resolvers are running at the same time.
  class Stats
    class_property running = 0
    class_property peak = 0
    class_property finished = 0

    def self.reset
      @@running = 0
      @@peak = 0
      @@finished = 0
    end
  end

  @[GraphQL::Object]
  class Item < GraphQL::BaseObject
    def initialize(@index : Int32)
    end

    @[GraphQL::Field]
    def value : Int32
      Stats.running += 1
      Stats.peak = Stats.running if Stats.running > Stats.peak
      # let other fibers run so true concurrency is observable
      3.times { Fiber.yield }
      Stats.running -= 1
      Stats.finished += 1
      @index
    end

    @[GraphQL::Field]
    def boom : Int32
      raise "boom" if @index == 0
      3.times { Fiber.yield }
      Stats.finished += 1
      @index
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def items(count : Int32) : Array(Item)
      Array.new(count) { |i| Item.new(i) }
    end
  end

  @[GraphQL::Object]
  class Mutation < GraphQL::BaseMutation
    class_property log = [] of Int32

    # Later steps sleep less, so concurrent execution would finish them first.
    @[GraphQL::Field]
    def step(n : Int32) : Int32
      (4 - n).times { Fiber.yield }
      Mutation.log << n
      n
    end

    @[GraphQL::Field]
    def items(count : Int32) : Array(Item)
      Array.new(count) { |i| Item.new(i) }
    end
  end

  class RaisingContext < GraphQL::Context
    def handle_exception(ex : ::Exception) : String?
      raise ex
    end
  end
end

describe "concurrency" do
  schema = GraphQL::Schema.new(ConcurrencyApi::Query.new)
  query = %({ items(count: 20) { value } })
  expected = {"data" => {"items" => Array.new(20) { |i| {"value" => i} }}}.to_json

  it "resolves sequentially by default" do
    ConcurrencyApi::Stats.reset
    ctx = GraphQL::Context.new

    schema.execute(query, context: ctx).should eq expected
    ConcurrencyApi::Stats.peak.should eq 1
    ctx.in_flight.should eq 0
  end

  it "runs resolvers concurrently within the budget" do
    ConcurrencyApi::Stats.reset
    ctx = GraphQL::Context.new
    ctx.max_concurrency = 4

    schema.execute(query, context: ctx).should eq expected
    ConcurrencyApi::Stats.peak.should be >= 2
    ConcurrencyApi::Stats.peak.should be <= 4
    ctx.in_flight.should eq 0
  end

  it "keeps the output in order when fibers finish out of order" do
    ctx = GraphQL::Context.new
    ctx.max_concurrency = 64

    schema.execute(query, context: ctx).should eq expected
  end

  it "resolves root mutation fields one after another" do
    ConcurrencyApi::Mutation.log.clear
    ctx = GraphQL::Context.new
    ctx.max_concurrency = 8
    mutation_schema = GraphQL::Schema.new(ConcurrencyApi::Query.new, ConcurrencyApi::Mutation.new)

    mutation_schema.execute(%(mutation { a: step(n: 1) b: step(n: 2) c: step(n: 3) }), context: ctx).should eq (
      {"data" => {"a" => 1, "b" => 2, "c" => 3}}
    ).to_json
    ConcurrencyApi::Mutation.log.should eq [1, 2, 3]
    ctx.in_flight.should eq 0
  end

  it "still resolves nested mutation fields concurrently" do
    ConcurrencyApi::Stats.reset
    ctx = GraphQL::Context.new
    ctx.max_concurrency = 4
    mutation_schema = GraphQL::Schema.new(ConcurrencyApi::Query.new, ConcurrencyApi::Mutation.new)

    mutation_schema.execute(%(mutation { items(count: 20) { value } }), context: ctx).should eq expected
    ConcurrencyApi::Stats.peak.should be >= 2
    ctx.in_flight.should eq 0
  end

  it "does not leak fibers when an element raises" do
    ConcurrencyApi::Stats.reset
    ctx = ConcurrencyApi::RaisingContext.new
    ctx.max_concurrency = 8

    expect_raises(Exception, "boom") do
      schema.execute(%({ items(count: 20) { boom } }), context: ctx)
    end

    # give the surviving fibers a chance to finish and release their permits
    20.times { Fiber.yield }

    ctx.in_flight.should eq 0
    ConcurrencyApi::Stats.finished.should eq 19
  end
end
