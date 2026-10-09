require "./language"

module GraphQL
  class Context
    # Maximum number of fields a single operation may select, counted
    # statically across the whole selection tree with fragments expanded.
    # `nil` (the default) disables the check. An operation that exceeds the
    # limit is rejected before any resolver runs.
    property max_complexity : Int32? = nil

    # Number of fields the executed operation selected, filled in by
    # `Schema#execute` before resolution starts.
    property complexity = 0
    property fragments : Array(Language::FragmentDefinition) = [] of Language::FragmentDefinition
    property query_type : String = ""
    property mutation_type : String? = nil
    property subscription_type : String? = nil
    property document : Language::Document?

    # Maximum number of fibers this execution may spawn at once to resolve
    # fields and array elements concurrently.
    #
    # `0` (the default) resolves everything sequentially in the calling fiber.
    # Any higher value lets up to that many resolvers run concurrently; once
    # the budget is used up, further work runs inline in the fiber that
    # requested it, so nesting can never deadlock and a single query can never
    # fan out into an unbounded number of fibers.
    #
    # Pick a value that your downstream resources can sustain. For example,
    # resolvers that check out database connections should stay below the
    # connection pool size.
    property max_concurrency : Int32 = 0

    @in_flight = Atomic(Int32).new(0)

    # Number of resolver fibers spawned by this execution that have not yet
    # finished.
    def in_flight : Int32
      @in_flight.get
    end

    # Return string message to be added to errors object or throw to bubble up
    def handle_exception(ex : ::Exception) : String?
      ex.message
    end

    # :nodoc:
    # Reserves one unit of the concurrency budget. Never blocks.
    def _graphql_acquire? : Bool
      loop do
        current = @in_flight.get
        return false if current >= @max_concurrency
        return true if @in_flight.compare_and_set(current, current + 1)[1]
      end
    end

    # :nodoc:
    def _graphql_release : Nil
      @in_flight.sub(1)
    end
  end
end
