#!/usr/bin/env bash
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/workspace/models}"
MODEL_PATH="${MODEL_PATH:-${MODEL_DIR}/jina-reranker-v3-BF16.gguf}"
PROJECTOR_PATH="${PROJECTOR_PATH:-${MODEL_DIR}/projector.safetensors}"
RERANK_PY_PATH="${RERANK_PY_PATH:-/workspace/rerank.py}"
PORT="${PORT:-7860}"
HOST="${HOST:-0.0.0.0}"
API_KEY="${API_KEY:-}"

if [[ -z "${API_KEY}" ]]; then
  echo "Error: API_KEY is required" >&2
  exit 1
fi

if [[ ! -f "${MODEL_PATH}" ]]; then
  echo "Error: model file not found at ${MODEL_PATH}" >&2
  exit 1
fi

if [[ ! -f "${PROJECTOR_PATH}" ]]; then
  echo "Error: projector file not found at ${PROJECTOR_PATH}" >&2
  exit 1
fi

if [[ ! -f "${RERANK_PY_PATH}" ]]; then
  echo "Error: rerank.py not found at ${RERANK_PY_PATH}" >&2
  exit 1
fi

find_bin() {
  local name="$1"
  shift
  local c
  for c in "$@"; do
    if [[ -x "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  command -v "$name" 2>/dev/null || true
}

LLAMA_EMBEDDING_PATH="$(find_bin llama-embedding \
  /usr/local/bin/llama-embedding \
  /opt/llama/llama-embedding \
  /opt/llama/bin/llama-embedding \
  /opt/llama/build/bin/llama-embedding)"

LLAMA_TOKENIZE_PATH="$(find_bin llama-tokenize \
  /usr/local/bin/llama-tokenize \
  /opt/llama/llama-tokenize \
  /opt/llama/bin/llama-tokenize \
  /opt/llama/build/bin/llama-tokenize)"

if [[ -z "${LLAMA_EMBEDDING_PATH}" ]]; then
  echo "Error: llama-embedding binary not found" >&2
  exit 1
fi

if [[ -z "${LLAMA_TOKENIZE_PATH}" ]]; then
  echo "Error: llama-tokenize binary not found" >&2
  exit 1
fi

export PATH="$(dirname "${LLAMA_TOKENIZE_PATH}"):${PATH}"
export LLAMA_EMBEDDING_PATH
export MODEL_PATH
export PROJECTOR_PATH
export HOST
export PORT
export API_KEY

exec python3 /workspace/server.py
