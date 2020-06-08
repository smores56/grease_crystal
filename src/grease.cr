require "http/status"

require "./db"
require "./cgi"
require "./handlers"

module Grease
  CGI.handle do |request|
    if request.method == "OPTIONS"
      cors
    else
      case request.path
      when "/graphql"
        response = graphql_response request
        TRANSACTION.commit
        response
      when "/graphiql"
        Graphiql.response
      when "/upload_frontend"
        upload_frontend request
      else
        with_content_type "Resource not found", "text/plain", HTTP::Status::NOT_FOUND
      end
    end
  rescue exception
    TRANSACTION.rollback
    with_content_type exception.to_s, "text/plain", HTTP::Status::BAD_REQUEST
  end
end
