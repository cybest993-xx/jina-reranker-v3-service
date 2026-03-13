# jina-reranker-v3-service

Background rerank service for `jina-reranker-v3-GGUF`, designed for separate deployment from your embedding service.

This project does **not** use FastAPI. It runs a lightweight Python HTTP server and exposes:

- `GET /health`
- `POST /rerank`
- `POST /v1/rerank`

## Model assets used

- `jina-reranker-v3-BF16.gguf`
- `projector.safetensors`
- `rerank.py`

All three are fetched from the official Hugging Face repo during image build.

## Build

```bash
docker build -t ghcr.io/cybest993-xx/jina-reranker-v3-service:latest .
```

## Run

```bash
docker run --rm \
  -p 7860:7860 \
  -e API_KEY=your-api-key \
  ghcr.io/cybest993-xx/jina-reranker-v3-service:latest
```

## Test

```bash
curl http://localhost:7860/health
```

```bash
curl -X POST http://localhost:7860/v1/rerank \
  -H "Authorization: Bearer your-api-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "jina-reranker-v3",
    "query": "OpenClaw memory plugin",
    "documents": [
      "OpenClaw supports plugins and memory.",
      "Today is sunny."
    ]
  }'
```

## Notes

- This service is intended for Hugging Face Spaces or other lightweight background deployments.
- It builds `llama-embedding` and `llama-tokenize` from Hanxiao's `llama.cpp` fork because the official model card recommends that route.
- Authentication accepts either:
  - `Authorization: Bearer <API_KEY>`
  - `Authorization: <API_KEY>`

## OpenClaw config snippet

```json
{
  "retrieval": {
    "mode": "hybrid",
    "vectorWeight": 0.7,
    "bm25Weight": 0.3,
    "rerank": "cross-encoder",
    "rerankProvider": "jina",
    "rerankEndpoint": "https://your-service.example.com/v1/rerank",
    "rerankModel": "jina-reranker-v3",
    "rerankApiKey": "YOUR_API_KEY"
  }
}
```
