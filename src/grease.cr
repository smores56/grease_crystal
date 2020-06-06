require "http/status"

require "./db"
require "./cgi"
require "./handlers"

module Grease
  CGI.handle do |request|
    case request.path
    when "/graphql"
      json = graphql_response request
      TRANSACTION.commit
      {json, "application/json", HTTP::Status::OK}
    when "/graphiql"
      {Graphiql.html, "text/html", HTTP::Status::OK}
    when "/upload_frontend"
      upload_frontend request
      {"OK", "text/plain", HTTP::Status::OK}
    else
      {"Resource not found", "text/plain", HTTP::Status::NOT_FOUND}
    end
  rescue exception
    TRANSACTION.rollback
    {exception.to_s, "text/plain", HTTP::Status::BAD_REQUEST}
  end
end
