module GraphQL::MutationType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end
end

module GraphQL
  abstract class BaseMutation
    macro inherited
      include GraphQL::ObjectType
      include GraphQL::MutationType
    end
  end
end
