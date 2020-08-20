module GraphQL::ScalarType
  abstract def to_json(builder : JSON::Builder)
end
