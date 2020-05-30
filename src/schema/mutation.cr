require "graphql"

@[GraphQL::Object]
class Mutation
  include GraphQL::ObjectType
  include GraphQL::MutationType

  @[GraphQL::Field]
  def echo(str : String) : String
    str
  end
end
