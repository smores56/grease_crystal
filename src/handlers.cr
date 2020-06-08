require "ecr"
require "json"
require "http"
require "graphql"

require "./utils"
require "./schema/query"
require "./schema/mutation"

module Grease
  def self.with_content_type(body, content_type, status = HTTP::Status::OK)
    headers = HTTP::Headers.new
    headers["Content-Type"] = content_type

    HTTP::Client::Response.new status, body, headers: headers
  end

  def self.graphql_response(request)
    schema = GraphQL::Schema.new Query.new, Mutation.new

    body = request.body || raise "JSON body is required"
    json = JSON.parse body

    query = json["query"].as_s? || raise "query was not provided"
    variables = json["variables"]?.try &.as_h?
    operation_name = json["operationName"]?.try &.as_s?

    context = UserContext.new get_token(request, variables)

    json = schema.execute(query, variables, operation_name, context)

    with_content_type json, "application/json"
  end

  def self.get_token(request, variables = nil)
    if token = request.headers["TOKEN"]?
      token
    elsif token = variables.try &.["token"]?
      token.as_s
    else
      nil
    end
  end

  def self.upload_frontend(request)
    context = UserContext.new (get_token request)
    context.logged_in!

    Utils.update_frontend(request.body || IO::Memory.new 0)

    with_content_type "OK", "text/plain"
  end

  class Graphiql
    @url = "graphql"

    ECR.def_to_s "templates/graphiql.html.ecr"

    def self.response
      Grease.with_content_type new.to_s, "text/html"
    end
  end

  def self.cors
    headers = HTTP::Headers.new
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "GET, POST, DELETE, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "token,access-control-allow-origin,content-type"
    headers["Allow"] = "GET, POST, DELETE, OPTIONS"
    headers["Content-Type"] = "text/plain"

    HTTP::Client::Response.new HTTP::Status::OK, "OK", headers: headers
  end
end
