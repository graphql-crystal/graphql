require "./annotations"

module GraphQL::QueryType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end

  @[GraphQL::Field(name: "__schema")]
  def _schema(context : ::GraphQL::Context) : GraphQL::Introspection::Schema
    ::GraphQL::Introspection::Schema.new(context.document.not_nil!, _graphql_type, context.mutation_type)
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
