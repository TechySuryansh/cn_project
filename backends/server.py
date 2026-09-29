#!/usr/bin/env python3
"""Tiny REST backend for the CN Phase-1 project (standard library only).

The application is deliberately trivial - the network is the project.
One implementation serves both Backend A and Backend B; identity comes from
the environment:

    BACKEND_ID=A|B  BACKEND_OWNER=Hardik  PORT=3001  BIND=0.0.0.0

Endpoints
    GET|HEAD /               small HTML confirmation page
    GET|HEAD /api/status     {"backend": "A", "owner": "...", "status": "ok"}
    GET|HEAD /health         200 "ok"
    GET|HEAD /api/cacheable  Cache-Control: max-age=60 + ETag, honours
                             If-None-Match with 304 Not Modified

Every response carries `X-Backend: <id>`.

The /api/cacheable body is IDENTICAL on A and B (identity only travels in the
header), so the ETag matches on both. That way a conditional request still
gets a 304 even if nginx routes it to the other backend.
"""
import hashlib
import json
import os
import signal
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND_ID = os.environ.get("BACKEND_ID", "A").upper()
BACKEND_OWNER = os.environ.get("BACKEND_OWNER", "unknown")
PORT = int(os.environ.get("PORT", "3001"))
BIND = os.environ.get("BIND", "0.0.0.0")  # NOT 127.0.0.1: other Macs must reach us

CACHEABLE_BODY = json.dumps(
    {"resource": "cacheable", "note": "identical on every backend", "version": 1},
    sort_keys=True,
).encode()
CACHEABLE_ETAG = '"%s"' % hashlib.sha256(CACHEABLE_BODY).hexdigest()[:16]


class Handler(BaseHTTPRequestHandler):
    server_version = "cn-backend/1.0"
    protocol_version = "HTTP/1.1"

    def _send(self, code, body=b"", ctype="application/json", extra=None):
        self.send_response(code)
        self.send_header("X-Backend", BACKEND_ID)
        if code != 304:
            self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)) if code != 304 else "0")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD" and code != 304:
            self.wfile.write(body)

    def _route(self):
        path = self.path.split("?", 1)[0]
        if path == "/":
            html = (
                "<!doctype html><title>Backend %s</title>"
                "<h1>Backend %s is running</h1><p>Owner: %s</p>\n"
                % (BACKEND_ID, BACKEND_ID, BACKEND_OWNER)
            ).encode()
            self._send(200, html, "text/html; charset=utf-8", {"Cache-Control": "no-cache"})
        elif path == "/api/status":
            body = json.dumps(
                {"backend": BACKEND_ID, "owner": BACKEND_OWNER, "status": "ok"}
            ).encode()
            self._send(200, body, extra={"Cache-Control": "no-store"})
        elif path == "/health":
            self._send(200, b"ok\n", "text/plain", {"Cache-Control": "no-store"})
        elif path == "/api/cacheable":
            headers = {"Cache-Control": "max-age=60", "ETag": CACHEABLE_ETAG}
            inm = self.headers.get("If-None-Match", "")
            if CACHEABLE_ETAG in [t.strip() for t in inm.split(",")] or inm.strip() == "*":
                self._send(304, extra=headers)
            else:
                self._send(200, CACHEABLE_BODY, extra=headers)
        else:
            self._send(404, json.dumps({"error": "not found"}).encode())

    def do_GET(self):  # noqa: N802
        self._route()

    do_HEAD = do_GET

    def log_message(self, fmt, *args):
        sys.stdout.write(
            "[backend %s] %s - %s\n" % (BACKEND_ID, self.address_string(), fmt % args)
        )
        sys.stdout.flush()


def main():
    httpd = ThreadingHTTPServer((BIND, PORT), Handler)
    httpd.daemon_threads = True

    def shutdown(signum, _frame):
        print("[backend %s] signal %s, shutting down" % (BACKEND_ID, signum), flush=True)
        threading.Thread(target=httpd.shutdown, daemon=True).start()

    signal.signal(signal.SIGTERM, shutdown)
    signal.signal(signal.SIGINT, shutdown)
    print(
        "[backend %s] owner=%s listening on http://%s:%d (pid %d)"
        % (BACKEND_ID, BACKEND_OWNER, BIND, PORT, os.getpid()),
        flush=True,
    )
    try:
        httpd.serve_forever()
    finally:
        httpd.server_close()
        print("[backend %s] stopped" % BACKEND_ID, flush=True)


if __name__ == "__main__":
    main()
