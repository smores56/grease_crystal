require "http/status"
require "./cgi"
require "./schema/handler"

CGI.handle do |request|
  # TODO: endpoint to upload frontend (as tar.gz)

  if request.path == "/graphiql"
    {Graphiql.html, "text/html", HTTP::Status::OK}
  else
    json = graphql_response request
    TRANSACTION.commit
    {json, "application/json", HTTP::Status::OK}
  end
rescue exception
  TRANSACTION.rollback
  {exception.to_s, "text/plain", HTTP::Status::BAD_REQUEST}
end
