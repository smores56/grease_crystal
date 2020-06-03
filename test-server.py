#!/usr/bin/env python

import BaseHTTPServer
import CGIHTTPServer

# Run the server
server = BaseHTTPServer.HTTPServer
handler = CGIHTTPServer.CGIHTTPRequestHandler
server_address = ("127.0.0.1", 8888)
handler.cgi_directories = ["/cgi-bin"]
httpd = server(server_address, handler)

httpd.serve_forever()
