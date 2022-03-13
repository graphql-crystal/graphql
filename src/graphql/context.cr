require "./language"

module GraphQL
  class Context
    property max_complexity : Int32?
    property complexity = 0
    property fragments : Array(Language::FragmentDefinition) = [] of Language::FragmentDefinition
    property query_type : String = ""
    property mutation_type : String? = nil
    property document : Language::Document?

    def initialize(@max_complexity = nil)
    end
  end
end
