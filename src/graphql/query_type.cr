module GraphQL::QueryType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end
end

module GraphQL
  abstract class BaseQuery
    macro inherited
      include GraphQL::ObjectType
      include GraphQL::QueryType
    end
  end
end
