module GraphQL::ScalarType
  abstract def to_json(builder : JSON::Builder)
end

module GraphQL
  abstract class BaseScalar
    macro inherited
      include GraphQL::ScalarType
    end
  end
end
