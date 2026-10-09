module GraphQL::SubscriptionType
  macro included
    macro finished
      include ::GraphQL::Document
    end
  end

  # :nodoc:
  # Starts the stream for a subscription operation's selection set. Errors
  # found before the stream exists are delivered as a single response on a
  # subscription that is already closed.
  def _graphql_subscribe(context, selections : Array(::GraphQL::Language::Selection)) : ::GraphQL::Subscription
    errors = [] of ::GraphQL::Error
    fields = Hash(String, ::GraphQL::Language::Field).new
    _graphql_collect_fields(context, selections, fields, errors)

    return ::GraphQL::Subscription.failed(errors) unless errors.empty?

    unless fields.size == 1
      return ::GraphQL::Subscription.failed([::GraphQL::Error.new("subscription operations must select exactly one root field")])
    end

    field = fields.first_value
    begin
      _graphql_subscribe_field(context, field)
    rescue ex : ::GraphQL::Exception
      ::GraphQL::Subscription.failed([::GraphQL::Error.new(ex.message.to_s, field._alias || field.name, field)])
    rescue ex
      message = context.handle_exception(ex) || "subscription failed"
      ::GraphQL::Subscription.failed([::GraphQL::Error.new(message, field._alias || field.name, field)])
    end
  end
end

module GraphQL
  abstract class BaseSubscription
    macro inherited
      include GraphQL::ObjectType
      include GraphQL::SubscriptionType
    end
  end
end
