require "ecr"
require "json"
require "graphql"
require "./query"
require "./mutation"

module Grease
  def self.graphql_response(request)
    schema = GraphQL::Schema.new Query.new, Mutation.new

    body = request.body || raise "JSON body is required"
    json = JSON.parse body

    query = json["query"].as_s? || raise "query was not provided"
    variables = json["variables"]?.try &.as_h
    operation_name = json["operationName"]?.try &.as_s

    context = UserContext.new get_token(request, variables)

    schema.execute(query, variables, operation_name, context)
  end

  def self.get_token(request, variables)
    if token = request.headers["TOKEN"]?
      token
    elsif token = variables.try &.["token"]?
      token.as_s
    else
      nil
    end
  end

  class Graphiql
    @url = "graphql"

    ECR.def_to_s "templates/graphiql.html.ecr"

    def self.html
      Graphiql.new.to_s
    end
  end
end
