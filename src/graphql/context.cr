require "./language"

module GraphQL
  class Context
    property max_complexity : Int32? = nil
    property complexity = 0
    property fragments : Array(Language::FragmentDefinition) = [] of Language::FragmentDefinition
    property query_type : String = ""
    property mutation_type : String? = nil
    property document : Language::Document?

    # Return string message to be added to errors object or throw to bubble up
    def handle_exception(ex : ::Exception) : String?
      ex.message
    end
  end
end
