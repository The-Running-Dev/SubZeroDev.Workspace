#!/usr/bin/env python3
"""Minimal Ollama native-API stand-in for Test-OllamaRuntime.ps1 tests.

Serves /api/version, /api/tags, /api/ps and a streamed /api/chat with fixed,
obviously synthetic metrics. It never runs a model.
"""
import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, HTTPServer

MODEL = "gemma4:12b"
SIZE = 8_000_000_000


class Handler(BaseHTTPRequestHandler):
    vram_fraction = 1.0
    include_cloud = False

    def _write_json(self, status, payload):
        content = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(content)))
        self.end_headers()
        self.wfile.write(content)

    def do_GET(self):
        if self.path == "/api/version":
            self._write_json(200, {"version": "0.0.0-mock"})
            return

        if self.path == "/api/tags":
            models = [{
                "name": MODEL,
                "model": MODEL,
                "size": SIZE,
                "digest": "0" * 64,
                "details": {"family": "gemma4", "parameter_size": "12B", "quantization_level": "Q4_K_M"},
            }]
            if self.include_cloud:
                models.append({
                    "name": "gemma4:31b-cloud",
                    "model": "gemma4:31b-cloud",
                    "remote_model": "gemma4:31b",
                    "remote_host": "https://ollama.com:443",
                    "size": 0,
                    "digest": "1" * 64,
                    "details": {"family": "gemma4"},
                })
            self._write_json(200, {"models": models})
            return

        if self.path == "/api/ps":
            self._write_json(200, {"models": [{
                "name": MODEL,
                "model": MODEL,
                "size": SIZE,
                "size_vram": int(SIZE * self.vram_fraction),
                "digest": "0" * 64,
                "context_length": 8192,
                "details": {"family": "gemma4", "parameter_size": "12B", "quantization_level": "Q4_K_M"},
            }]})
            return

        self._write_json(404, {"error": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        body = json.loads(self.rfile.read(length) or b"{}")

        if self.path != "/api/chat":
            self._write_json(404, {"error": "not found"})
            return

        if body.get("model") != MODEL:
            self._write_json(404, {"error": f"model '{body.get('model')}' not found"})
            return

        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        for piece in ["mock", " reply"]:
            line = {"model": MODEL, "message": {"role": "assistant", "content": piece}, "done": False}
            self.wfile.write((json.dumps(line) + "\n").encode("utf-8"))
            self.wfile.flush()
            time.sleep(0.01)
        final = {
            "model": MODEL,
            "message": {"role": "assistant", "content": ""},
            "done": True,
            "done_reason": "stop",
            "total_duration": 2_000_000_000,
            "load_duration": 500_000_000,
            "prompt_eval_count": 40,
            "prompt_eval_duration": 200_000_000,
            "eval_count": 100,
            "eval_duration": 1_000_000_000,
        }
        self.wfile.write((json.dumps(final) + "\n").encode("utf-8"))

    def log_message(self, format, *args):
        return


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--vram-fraction", type=float, default=1.0)
    parser.add_argument("--include-cloud", action="store_true")
    args = parser.parse_args()

    Handler.vram_fraction = args.vram_fraction
    Handler.include_cloud = args.include_cloud

    HTTPServer(("127.0.0.1", args.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
