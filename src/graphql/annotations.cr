module GraphQL
  annotation Object
  end

  # Marks an abstract class or module as a GraphQL interface. Objects that
  # inherit from or include it implement the interface.
  annotation Interface
  end

  # Marks a module as a GraphQL union. Objects that include it are its
  # member types.
  annotation Union
  end

  annotation InputObject
  end

  annotation Field
  end

  annotation Enum
  end

  annotation Scalar
  end
end
