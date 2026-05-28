FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git \
        rsync fd-find ripgrep shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 — needed by Hermes for WhatsApp bridge and MCP servers
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install hadolint (Dockerfile linter)
RUN curl -Lo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint
