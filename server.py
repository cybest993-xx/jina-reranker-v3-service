#!/usr/bin/env python3
import json
import os
import pathlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

from rerank import GGUFReranker

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "7860"))
API_KEY = os.environ.get("API_KEY", "")
MODEL_PATH = os.environ.get("MODEL_PATH", "/workspace/models/jina-reranker-v3-BF16.gguf")
PROJECTOR_PATH = os.environ.get("PROJECTOR_PATH", "/workspace/models/projector.safetensors")
LLAMA_EMBEDDING_PATH = os.environ.get("LLAMA_EMBEDDING_PATH", "/usr/local/bin/llama-embedding")

reranker = GGUFReranker(
    model_path=MODEL_PATH,
    projector_path=PROJECTOR_PATH,
    llama_embedding_path=LLAMA_EMBEDDING_PATH,
)


def _json(handler, code, payload):
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    handler.send_response(code)
    handler.send_header("Content-Type", "application/json; charset=utf-8")
    handler.send_header("Content-Length", str(len(data)))
    handler.end_headers()
    handler.wfile.write(data)


def _authorized(handler):
    if not API_KEY:
        return True
    auth = handler.headers.get("Authorization", "")
    raw = auth.strip()
    if raw == API_KEY:
        return True
    if raw.lower().startswith("bearer ") and raw[7:].strip() == API_KEY:
        return True
    return False


class Handler(BaseHTTPRequestHandler):
    server_version = "jina-reranker-v3-service/0.1"

    def log_message(self, fmt, *args):
        print("%s - - [%s] %s" % (self.address_string(), self.log_date_time_string(), fmt % args), flush=True)

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/health":
            return _json(self, 200, {"status": "ok", "model": pathlib.Path(MODEL_PATH).name})
        return _json(self, 404, {"error": {"code": 404, "message": "Not Found"}})

    def do_POST(self):
        path = urlparse(self.path).path
        if path not in ("/rerank", "/v1/rerank"):
            return _json(self, 404, {"error": {"code": 404, "message": "Not Found"}})

        if not _authorized(self):
            return _json(self, 401, {"error": {"message": "Invalid API Key", "type": "authentication_error", "code": 401}})

        try:
            length = int(self.headers.get("Content-Length", "0"))
            raw = self.rfile.read(length)
            body = json.loads(raw.decode("utf-8")) if raw else {}
        except Exception:
            return _json(self, 400, {"error": {"code": 400, "message": "Invalid JSON body"}})

        query = body.get("query")
        documents = body.get("documents")
        model = body.get("model") or "jina-reranker-v3"
        top_n = body.get("top_n")
        instruction = body.get("instruction")

        if not isinstance(query, str) or not query.strip():
            return _json(self, 400, {"error": {"code": 400, "message": "`query` must be a non-empty string"}})
        if not isinstance(documents, list) or not all(isinstance(x, str) for x in documents) or not documents:
            return _json(self, 400, {"error": {"code": 400, "message": "`documents` must be a non-empty string array"}})

        try:
            results = reranker.rerank(query=query, documents=documents, top_n=top_n, instruction=instruction)
        except Exception as e:
            return _json(self, 500, {"error": {"code": 500, "message": str(e)}})

        payload = {
            "model": model,
            "results": [
                {"index": item["index"], "relevance_score": item["relevance_score"]}
                for item in results
            ]
        }
        return _json(self, 200, payload)


if __name__ == "__main__":
    print(f"Starting rerank service on {HOST}:{PORT}", flush=True)
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    httpd.serve_forever()
