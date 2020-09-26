require "http/server"
require "option_parser"

cgi_file = nil.as String?
port = 5555

OptionParser.parse do |parser|
  parser.banner = "Usage: test_server [arguments]"

  parser.on("-f FILE", "--file", "CGI file to handle requests with") { |f| cgi_file = f }
  parser.on("-p PORT", "--port", "The port to serve on") { |new_port| port = new_port.to_i }
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

cgi = if f = cgi_file
        raise "CGI file does not exist" unless File.exists? f
        f
      else
        raise "Must provide a CGI file"
      end

server = HTTP::Server.new do |context|
  body = context.request.body || IO::Memory.new
  cgi_env = {
    "CONTENT_LENGTH" => context.request.content_length.to_s,
    "REQUEST_METHOD" => context.request.method,
    "PATH_INFO"      => context.request.path,
  }
  context.request.headers.each do |key, values|
    if val = values.first?
      cgi_env["HTTP_#{key}"] = val
    end
  end

  process = Process.new cgi, env: cgi_env, input: body,
    output: Process::Redirect::Pipe, error: Process::Redirect::Pipe

  response = process.output.gets_to_end.split "\n\n", limit: 2
  headers, content = response[0], response[1] || ""

  raise "Script returned error" unless process.wait.success?

  headers.lines.each do |header|
    if status = /^Status: (\d+)/.match header
      context.response.status = HTTP::Status.new status[1].to_i
    else
      items = header.split ": "
      key, value = items[0], items[1]? || ""
      context.response.headers[key] = value
      context.response.content_type = value if key == "Content-Type"
    end
  end

  context.response.output << content
rescue exception
  context.response.status = HTTP::Status.new 500
  context.response.content_type = "text/plain"
  context.response.output << exception.to_s << "\n"
  context.response.output << exception.backtrace? << "\n"
end

address = server.bind_tcp port
puts "Listening on http://#{address}"
server.listen
