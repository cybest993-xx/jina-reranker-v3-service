FROM ubuntu:24.04

LABEL org.opencontainers.image.source="https://github.com/cybest993-xx/jina-reranker-v3-service"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1

ARG LLAMA_CPP_REPO=https://github.com/hanxiao/llama.cpp.git
ARG LLAMA_CPP_REF=main
ARG MODEL_URL=https://huggingface.co/jinaai/jina-reranker-v3-GGUF/resolve/main/jina-reranker-v3-BF16.gguf
ARG PROJECTOR_URL=https://huggingface.co/jinaai/jina-reranker-v3-GGUF/resolve/main/projector.safetensors
ARG RERANK_PY_URL=https://huggingface.co/jinaai/jina-reranker-v3-GGUF/resolve/main/rerank.py

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    make \
    g++ \
    python3 \
    python3-pip \
    python3-venv \
    libgomp1 \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --break-system-packages --no-cache-dir numpy safetensors

WORKDIR /opt
RUN git clone --depth=1 --branch "${LLAMA_CPP_REF}" "${LLAMA_CPP_REPO}" /opt/llama.cpp
WORKDIR /opt/llama.cpp
RUN make llama-embedding llama-tokenize

WORKDIR /workspace
RUN mkdir -p /workspace/models \
    && curl -fsSL "${MODEL_URL}" -o /workspace/models/jina-reranker-v3-BF16.gguf \
    && curl -fsSL "${PROJECTOR_URL}" -o /workspace/models/projector.safetensors \
    && curl -fsSL "${RERANK_PY_URL}" -o /workspace/rerank.py

COPY server.py /workspace/server.py
COPY start.sh /workspace/start.sh
RUN chmod 0755 /workspace/start.sh

EXPOSE 7860

CMD ["/workspace/start.sh"]
