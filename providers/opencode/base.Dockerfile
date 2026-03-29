# providers/opencode/base.Dockerfile
# Stable install layers for the OpenCode reasoning layer.
# Built once per provider; rebuilt only when system packages or the opencode-ai package version changes.
# Tagged as opencode-base (no project suffix — contains no project-specific content).
# Built by scripts/build_container.sh --type=agent --provider=opencode.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

# -------------------------
# System packages
# -------------------------
RUN apt-get update && apt-get install -y \
    bash curl git ca-certificates \
    python3 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Install OpenCode
# -------------------------
RUN npm install -g opencode-ai
