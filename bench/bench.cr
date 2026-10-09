# End-to-end benchmark of `Schema#execute`.
#
# Run it before and after a change and compare:
#
#     crystal run --release bench/bench.cr -- --json /tmp/before.json
#     # ... make changes ...
#     crystal run --release bench/bench.cr -- --compare /tmp/before.json
#
# Each scenario is a realistic request against a schema with an interface, a
# union, an enum, an input object, custom scalars, lists and nesting. Every
# response is checked for errors first, then the scenario runs for a fixed
# wall-clock budget and reports throughput. Numbers are only comparable
# between runs on the same machine with the same compiler flags.
require "option_parser"
require "json"
require "../src/graphql"

module Bench
  @[GraphQL::Enum]
  enum Role
    Admin
    Member
    Guest
  end

  @[GraphQL::Union]
  module SearchResult
  end

  @[GraphQL::Interface]
  abstract class Node < GraphQL::BaseObject
    @[GraphQL::Field]
    abstract def id : GraphQL::Scalars::ID
  end

  @[GraphQL::Object]
  class Comment < Node
    def initialize(@n : Int32)
    end

    @[GraphQL::Field]
    def id : GraphQL::Scalars::ID
      GraphQL::Scalars::ID.new("c#{@n}")
    end

    @[GraphQL::Field]
    def text : String
      "Comment number #{@n} with a little bit of text in it"
    end

    @[GraphQL::Field]
    def likes : Int32
      @n % 17
    end

    @[GraphQL::Field]
    def author : User
      User.new(@n % 50)
    end
  end

  @[GraphQL::Object]
  class Post < Node
    include SearchResult

    def initialize(@n : Int32)
    end

    @[GraphQL::Field]
    def id : GraphQL::Scalars::ID
      GraphQL::Scalars::ID.new("p#{@n}")
    end

    @[GraphQL::Field]
    def title : String
      "Post #{@n}"
    end

    @[GraphQL::Field]
    def body : String?
      @n % 7 == 0 ? nil : "Body of post #{@n}. " * 4
    end

    @[GraphQL::Field]
    def score : Float64
      @n * 0.25
    end

    @[GraphQL::Field]
    def published : Bool
      @n.even?
    end

    @[GraphQL::Field]
    def tags : Array(String)
      ["crystal", "graphql", "tag#{@n % 5}"]
    end

    @[GraphQL::Field]
    def comments(limit : Int32 = 5) : Array(Comment)
      Array.new(limit) { |i| Comment.new(@n * 100 + i) }
    end
  end

  @[GraphQL::Object]
  class User < Node
    include SearchResult

    def initialize(@n : Int32)
    end

    @[GraphQL::Field]
    def id : GraphQL::Scalars::ID
      GraphQL::Scalars::ID.new("u#{@n}")
    end

    @[GraphQL::Field]
    def name : String
      "User #{@n}"
    end

    @[GraphQL::Field]
    def email : String?
      @n % 3 == 0 ? nil : "user#{@n}@example.com"
    end

    @[GraphQL::Field]
    def role : Role
      Role.from_value(@n % 3)
    end

    @[GraphQL::Field]
    def posts(limit : Int32 = 10) : Array(Post)
      Array.new(limit) { |i| Post.new(@n * 100 + i) }
    end
  end

  @[GraphQL::InputObject]
  class UserInput < GraphQL::BaseInputObject
    getter name : String
    getter email : String?
    getter role : Role

    @[GraphQL::Field]
    def initialize(@name : String, @role : Role, @email : String? = nil)
    end
  end

  @[GraphQL::Object]
  class Query < GraphQL::BaseQuery
    @[GraphQL::Field]
    def users(count : Int32) : Array(User)
      Array.new(count) { |i| User.new(i) }
    end

    @[GraphQL::Field]
    def user(id : GraphQL::Scalars::ID) : User?
      User.new(id.value.lchop("u").to_i? || 0)
    end

    @[GraphQL::Field]
    def search(text : String, count : Int32) : Array(SearchResult)
      Array(SearchResult).new(count) { |i| i.even? ? User.new(i).as(SearchResult) : Post.new(i).as(SearchResult) }
    end
  end

  @[GraphQL::Object]
  class Mutation < GraphQL::BaseMutation
    @[GraphQL::Field]
    def create_user(input : UserInput) : User
      User.new(input.name.size + input.role.value)
    end
  end

  SCHEMA = GraphQL::Schema.new(Query.new, Mutation.new)

  record Scenario, name : String, query : String, variables : Hash(String, JSON::Any)? = nil, concurrency : Int32 = 0 do
    def context : GraphQL::Context
      ctx = GraphQL::Context.new
      ctx.max_concurrency = concurrency
      ctx
    end
  end

  NESTED = <<-GRAPHQL
    query Nested($count: Int!) {
      users(count: $count) {
        id name email role
        posts(limit: 10) {
          id title body score published tags
          comments(limit: 5) {
            id text likes
            author { id name }
          }
        }
      }
    }
    GRAPHQL

  SCENARIOS = [
    # per-request overhead: parsing, validation, one tiny object
    Scenario.new("small", %({ user(id: "u1") { id name role } })),
    # many objects, scalar fields only
    Scenario.new("flat_list", %({ users(count: 5000) { id name email role } })),
    # five levels, 100 users x 10 posts x 5 comments
    Scenario.new("nested_tree", NESTED, {"count" => JSON::Any.new(100_i64)}),
    # the same tree resolved with a fiber budget
    Scenario.new("nested_concurrent", NESTED, {"count" => JSON::Any.new(100_i64)}, concurrency: 16),
    # union members selected through inline fragments and a spread
    Scenario.new("union_fragments", <<-GRAPHQL),
      {
        search(text: "crystal", count: 3000) {
          __typename
          ... on User { id name role }
          ...PostFields
        }
      }
      fragment PostFields on Post { id title score published }
      GRAPHQL
    # 100 serial root fields with input objects, through variables
    Scenario.new("mutations", String.build { |q|
      q << "mutation Create($role: Role!) {\n"
      100.times { |i| q << "  m#{i}: createUser(input: {name: \"user #{i}\", email: \"u#{i}@example.com\", role: $role}) { id name role }\n" }
      q << "}"
    }, {"role" => JSON::Any.new("Member")}),
    # the full introspection query a client sends on connect
    Scenario.new("introspection", GraphQL::INTROSPECTION_QUERY),
  ]

  record Result, name : String, bytes : Int32, requests : Int32, seconds : Float64 do
    include JSON::Serializable

    def per_second : Float64
      requests / seconds
    end

    def ms_per_request : Float64
      seconds * 1000 / requests
    end

    def mb_per_second : Float64
      bytes.to_f * requests / seconds / 1_000_000
    end
  end

  def self.run(scenario : Scenario, budget : Time::Span) : Result
    response = SCHEMA.execute(scenario.query, scenario.variables, nil, scenario.context)
    if response.includes?(%("errors"))
      abort "scenario #{scenario.name} returned errors:\n#{response[0, 400]}"
    end

    3.times { SCHEMA.execute(scenario.query, scenario.variables, nil, scenario.context) }

    requests = 0
    elapsed = Time::Span.zero
    while elapsed < budget
      elapsed += Time.measure { SCHEMA.execute(scenario.query, scenario.variables, nil, scenario.context) }
      requests += 1
    end

    Result.new(scenario.name, response.bytesize, requests, elapsed.total_seconds)
  end

  def self.main
    budget = 2.seconds
    only = nil
    json_path = nil
    compare_path = nil

    OptionParser.parse do |parser|
      parser.banner = "Usage: crystal run --release bench/bench.cr -- [options]"
      parser.on("--seconds SECONDS", "Time budget per scenario (default 2)") { |s| budget = s.to_f.seconds }
      parser.on("--only NAME", "Run one scenario") { |n| only = n }
      parser.on("--json PATH", "Write results to PATH") { |p| json_path = p }
      parser.on("--compare PATH", "Show the change against results written with --json") { |p| compare_path = p }
      parser.on("-h", "--help", "Show this help") { puts parser; exit }
    end

    baseline = compare_path.try { |p| Array(Result).from_json(File.read(p)).index_by(&.name) }
    scenarios = only ? SCENARIOS.select { |s| s.name == only } : SCENARIOS
    abort "no scenario named #{only}" if scenarios.empty?

    puts "crystal #{Crystal::VERSION}, #{budget.total_seconds}s per scenario, release build: #{{{ flag?(:release) }}}"
    puts
    header = "%-18s %10s %10s %10s %8s" % ["scenario", "bytes", "req/s", "ms/req", "MB/s"]
    header += " %10s" % "vs before" if baseline
    puts header
    puts "-" * header.size

    results = scenarios.map do |scenario|
      result = run(scenario, budget)
      line = "%-18s %10d %10.1f %10.3f %8.1f" % [result.name, result.bytes, result.per_second, result.ms_per_request, result.mb_per_second]
      if baseline && (before = baseline[result.name]?)
        change = (result.per_second / before.per_second - 1) * 100
        line += " %+9.1f%%" % change
      end
      puts line
      result
    end

    if path = json_path
      File.write(path, results.to_pretty_json)
      puts "\nwrote #{path}"
    end
  end
end

Bench.main
