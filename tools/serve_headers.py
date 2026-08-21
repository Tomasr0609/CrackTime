import http.server, socketserver, functools, sys

class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "cross-origin")
        super().end_headers()
    def log_message(self, *a):
        pass

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8124
with socketserver.ThreadingTCPServer(("127.0.0.1", PORT), functools.partial(H, directory=".")) as httpd:
    print(f"serving on {PORT} with COEP/COOP")
    httpd.serve_forever()