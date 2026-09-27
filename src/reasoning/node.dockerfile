FROM node:22.22.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git \
        rsync fd-find ripgrep shellcheck jq \
    && rm -rf /var/lib/apt/lists/*

# Install hadolint (Dockerfile linter)
RUN curl -Lo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint

# Install markdownlint-cli2 (Markdown linter; gate via scripts/check_markdown.sh)
RUN npm install -g markdownlint-cli2@0.23.2
