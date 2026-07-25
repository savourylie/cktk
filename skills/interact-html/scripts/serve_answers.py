#!/usr/bin/env python3
"""One-shot answer collector for the interact-html skill.

Usage: serve_answers.py --dir DIR --slug SLUG [--timeout SECONDS]

Binds a free 127.0.0.1 port, atomically writes it to DIR/SLUG.port, then waits
for one POST /answers with a JSON body. Writes the body atomically to
DIR/SLUG.answers.json and exits 0. POST /cancel exits without writing.
Exits 1 if the timeout elapses first. Stdlib only; no external requests.
"""
import argparse
import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer


def atomic_write(path, data):
    tmp = path + ".tmp"
    with open(tmp, "wb") as fh:
        fh.write(data)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--slug", required=True)
    ap.add_argument("--timeout", type=int, default=900)
    args = ap.parse_args()
    out = os.path.join(args.dir, args.slug + ".answers.json")
    port_file = os.path.join(args.dir, args.slug + ".port")
    state = {"answered": False, "stop": False}

    class Handler(BaseHTTPRequestHandler):
        def _headers(self, code, body=b""):
            self.send_response(code)
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
            self.send_header("Access-Control-Allow-Headers", "Content-Type")
            self.send_header("Access-Control-Allow-Private-Network", "true")
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            if body:
                self.wfile.write(body)

        def do_OPTIONS(self):
            self._headers(204)

        def do_POST(self):
            if self.path == "/cancel":
                state["stop"] = True
                self._headers(200, b'{"status":"cancelled"}')
                return
            body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
            try:
                json.loads(body)
            except ValueError:
                self._headers(400, b'{"error":"invalid JSON"}')
                return
            atomic_write(out, body)
            state["answered"] = True
            self._headers(200, b'{"status":"received"}')

        def log_message(self, *_):
            pass

    os.makedirs(args.dir, exist_ok=True)
    server = HTTPServer(("127.0.0.1", 0), Handler)
    server.timeout = 1
    atomic_write(port_file, str(server.server_address[1]).encode())
    deadline = time.monotonic() + args.timeout
    try:
        while not (state["answered"] or state["stop"]) and time.monotonic() < deadline:
            server.handle_request()
    finally:
        server.server_close()
        try:
            os.remove(port_file)
        except OSError:
            pass
    sys.exit(0 if state["answered"] else 1)


if __name__ == "__main__":
    main()
