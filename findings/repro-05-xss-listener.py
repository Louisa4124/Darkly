import http.server, socketserver, datetime
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        with open('/tmp/xss_listener/hits.log','a') as f:
            f.write(f"{datetime.datetime.now()} {self.client_address[0]} {fmt%args}\n")
    def do_GET(self):
        with open('/tmp/xss_listener/hits.log','a') as f:
            f.write(f"{datetime.datetime.now()} GET {self.path} from {self.client_address[0]} headers={dict(self.headers)}\n")
        self.send_response(200)
        self.send_header('Content-Type','text/plain')
        self.end_headers()
        self.wfile.write(b'ok')
    def do_POST(self):
        length = int(self.headers.get('Content-Length',0))
        body = self.rfile.read(length)
        with open('/tmp/xss_listener/hits.log','a') as f:
            f.write(f"{datetime.datetime.now()} POST {self.path} from {self.client_address[0]} body={body}\n")
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin','*')
        self.end_headers()
        self.wfile.write(b'ok')
with socketserver.TCPServer(('0.0.0.0', 8888), H) as httpd:
    httpd.serve_forever()
