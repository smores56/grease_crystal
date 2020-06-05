require "http/status"
require "./cgi"
require "./schema/handler"

module Grease
  CGI.handle do |request|
    # TODO: endpoint to upload frontend (as tar.gz)
    case request.path
    when "/graphiql"
      {Graphiql.html, "text/html", HTTP::Status::OK}
    when "/graphql"
      json = graphql_response request
      TRANSACTION.commit
      {json, "application/json", HTTP::Status::OK}
    else
      {"Resource not found", "text/plain", HTTP::Status::NOT_FOUND}
    end
  rescue exception
    TRANSACTION.rollback
    {exception.to_s, "text/plain", HTTP::Status::BAD_REQUEST}
  end
end
