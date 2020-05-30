require "json"
require "graphql"
require "http/status"

require "./cgi"
require "./schema/*"
require "./models/db"

schema = GraphQL::Schema.new Query.new, Mutation.new

begin
  request = CGI.request_from_stdin
  body = request.body || raise "JSON body is required"
  json = JSON.parse body

  context = UserContext.new request.headers["TOKEN"]?

  query = json["query"].as_s? || raise "query was not provided"
  variables = json["variables"]?.as(Hash(String, JSON::Any)?)
  operation_name = json["operationName"]?.as(String?)

  json = schema.execute(query, variables, operation_name, context)
  TRANSACTION.commit

  CGI.response_to_stdout(json, HTTP::Status::OK)
rescue exception
  TRANSACTION.rollback

  error_json = {"error": exception.to_s}.to_json
  CGI.response_to_stdout(error_json, HTTP::Status::BAD_REQUEST)
end
