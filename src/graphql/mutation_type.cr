module GraphQL::MutationType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end
end
