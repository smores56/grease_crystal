require "graphql"
require "./models"
require "./grades"

module Models
  @[GraphQL::Object]
  class MemberPermission
    include GraphQL::ObjectType

    def initialize(@name : String, @event_type : String?)
    end

    @[GraphQL::Field]
    def name : String
      @name
    end

    @[GraphQL::Field]
    def event_type : String?
      @event_type
    end
  end
end
