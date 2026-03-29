# providers/hermes/base.Dockerfile
# Stable install layers for the Hermes reasoning layer.
# Built once; rebuilt only when system packages, runtimes, or agent source change.
# Tagged as hermes-base (no project suffix — contains no project-specific content).
#
# Based on the upstream Docker PR: NousResearch/hermes-agent#1841
# Applies reviewer suggestions: layered apt, --no-cache-dir, npm ci,
# pinned base image, combined RUN steps for smaller layers.
#
# Installation approach follows the official install script:
# https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh
# Key alignments:
#   - uv used for Python dependency management instead of pip directly
# Note: mini-swe-agent submodule was removed in hermes-agent#2804 — all terminal
# backends are now inlined. Plain git clone is sufficient; no submodule init needed.
FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

# -------------------------
# System packages (root)
# -------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl git ca-certificates \
        nodejs npm \
        python3 python3-pip \
        ripgrep ffmpeg \
        gcc python3-dev libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Install uv (fast Python package manager)
# -------------------------
RUN pip install uv --break-system-packages --no-cache-dir

# -------------------------
# Install Hermes from source (root)
# -------------------------
RUN git clone https://github.com/NousResearch/hermes-agent /opt/hermes
WORKDIR /opt/hermes

RUN uv venv venv --python 3.11
ENV VIRTUAL_ENV=/opt/hermes/venv
ENV PATH="/opt/hermes/venv/bin:$PATH"

RUN uv pip install -e ".[all]" --no-cache-dir

RUN npm ci && \
    npx playwright install --with-deps chromium
