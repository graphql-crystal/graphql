module GraphQL::QueryType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end
end
