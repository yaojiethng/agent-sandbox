# providers/hermes/base.Dockerfile
# Stable install layers for the Hermes reasoning layer.
# Built once per provider; rebuilt only when system packages, runtimes, or agent source change.
# Tagged as hermes-base (no project suffix — contains no project-specific content).
# Built by scripts/build_container.sh --type=agent --provider=hermes.
#
# Multi-stage build: builder compiles Python packages; runtime copies the venv
# without carrying build tools (gcc, python3-dev, libffi-dev) into the final image.
#
# Based on the upstream Docker PR: NousResearch/hermes-agent#1841 (Aralobster rewrite)
# Key changes vs original:
#   - Multi-stage build — build tools excluded from runtime image
#   - python:3.11-slim base — pinned Python version, smaller than debian:bookworm
#   - Node.js 20 via NodeSource — current LTS, explicit version pin
#   - Playwright removed — use Browserbase/CDP instead
#   - uv used exclusively for venv creation and package installation

# ── Stage 1: Builder ────────────────────────────────────────────
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc python3-dev libffi-dev git curl \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 (WhatsApp bridge, MCP servers)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install uv via official installer — used exclusively for venv + packages
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

WORKDIR /opt/hermes

# Clone Hermes source
RUN git clone https://github.com/NousResearch/hermes-agent /opt/hermes

# Create venv and install all extras via uv
RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python --no-cache-dir -e ".[all]"

# Install npm dependencies (no devDependencies)
RUN npm install --omit=dev

# ── Stage 2: Runtime ────────────────────────────────────────────
FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates \
        ripgrep ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 runtime (no build tools needed)
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# uv in runtime — needed for MCP tool support at runtime
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Copy built venv and Hermes source from builder
COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/hermes /opt/hermes

WORKDIR /opt/hermes

ENV PATH="/opt/venv/bin:/root/.local/bin:/usr/local/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONUNBUFFERED=1
