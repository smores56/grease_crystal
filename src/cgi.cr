require "http"

module CGI
  BASE_HEADERS = {
    "AUTH_TYPE"         => "X-CGI-Auth-Type",
    "CONTENT_LENGTH"    => "X-CGI-Content-Length",
    "CONTENT_TYPE"      => "X-CGI-Content-Type",
    "GATEWAY_INTERFACE" => "X-CGI-Gateway-Interface",
    "PATH_INFO"         => "X-CGI-Path-Info",
    "PATH_TRANSLATED"   => "X-CGI-Path-Translated",
    "QUERY_STRING"      => "X-CGI-Query-String",
    "REMOTE_ADDR"       => "X-CGI-Remote-Addr",
    "REMOTE_HOST"       => "X-CGI-Remote-Host",
    "REMOTE_IDENT"      => "X-CGI-Remote-Ident",
    "REMOTE_USER"       => "X-CGI-Remote-User",
    "REQUEST_METHOD"    => "X-CGI-Request-Method",
    "SCRIPT_NAME"       => "X-CGI-Script-Name",
    "SERVER_PORT"       => "X-CGI-Server-Port",
    "SERVER_PROTOCOL"   => "X-CGI-Server-Protocol",
    "SERVER_SOFTWARE"   => "X-CGI-Server-Software",
  }

  def self.request_from_stdin
    length = ENV["CONTENT_LENGTH"]?.try &.to_i? || 0
    body = Bytes.new length
    STDIN.read_fully body

    method = ENV["REQUEST_METHOD"]? || "GET"
    path = ENV["PATH_INFO"]? || raise "PATH_INFO is required"
    uri = if query = ENV["QUERY_STRING"]?
            "#{path}?#{query}"
          else
            path
          end

    return HTTP::Request.new method, uri, parse_headers, body, (ENV["SERVER_PROTOCOL"]? || "HTTP/1.1")
  end

  def self.parse_headers
    headers = HTTP::Headers.new
    BASE_HEADERS.each do |env_var, name|
      if val = ENV[env_var]?
        headers[name] = val
      end
    end

    ENV.each do |key, value|
      if key.starts_with?("HTTP_")
        headers[key[5..]] = value
      end
    end

    return headers
  end

  def self.response_to_stdout(body, content_type, status)
    STDOUT << "Status: #{status.code} #{status.description}\n"
    STDOUT << "Content-type: #{content_type}\n\n"
    STDOUT << body
  end

  def self.handle(&block)
    CGI.response_to_stdout(*yield CGI.request_from_stdin)
  end
end
