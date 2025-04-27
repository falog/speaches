ARG BASE_IMAGE=nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04
# hadolint ignore=DL3006
FROM ${BASE_IMAGE}
LABEL org.opencontainers.image.source="https://github.com/speaches-ai/speaches"
LABEL org.opencontainers.image.licenses="MIT"

# `ffmpeg`は音声処理に必要
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends curl ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# `ubuntu`ユーザー作成
RUN useradd --create-home --shell /bin/bash --uid 1000 ubuntu || true
USER ubuntu
ENV HOME=/home/ubuntu \
    PATH=/home/ubuntu/.local/bin:$PATH
WORKDIR $HOME/speaches

# `uv`ツールのインストール
COPY --chown=ubuntu --from=ghcr.io/astral-sh/uv:0.6.1 /uv /bin/uv

# キャッシュのマウント設定
RUN --mount=type=cache,id=cache-key-uv-cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --compile-bytecode --no-install-project

COPY --chown=ubuntu . .

# 再度キャッシュを使用して同期
#RUN --mount=type=cache,id=cache-key-uv-cache,target=/root/.cache/uv \
#    uv sync --frozen --compile-bytecode --extra ui

# HuggingFaceのキャッシュディレクトリ作成
#RUN mkdir -p $HOME/.cache/huggingface/hub

# 環境変数の設定
ENV UVICORN_HOST=0.0.0.0
ENV UVICORN_PORT=8000
ENV PATH="$HOME/speaches/.venv/bin:$PATH"
ENV HF_HUB_ENABLE_HF_TRANSFER=0
ENV DO_NOT_TRACK=1

# ポートの公開
EXPOSE 8000

# アプリケーション起動
CMD ["uvicorn", "--factory", "speaches.main:create_app"]
