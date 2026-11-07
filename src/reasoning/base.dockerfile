# reasoning/base.dockerfile
# Shared runtime base for every reasoning layer provider (opencode, pi).
# Tagged as agent-base. Built by scripts/build.sh --type=agent as tier 1, and
# cached across all providers on this machine.
#
# What lives here and what does not:
#   Here  -- the runtime set every agent may assume: Node, Python, uv, the
#            shared CLI tools, and the repo lint gates (hadolint,
#            markdownlint-cli2, shellcheck). A provider base adds only its
#            agent install.
#   Not here -- any provider's agent package, config, or project content.
#
# Python comes from uv, not from apt. Debian bookworm, the base of
# node:22.22.3-slim, ships python3 3.11.2, which is below the 3.11.12 floor
# the harness requires. uv installs the pinned 3.11 patch into /opt/uv-python,
# and UV_PYTHON_INSTALL_DIR points at it so a provider base can `uv venv`
# without repeating the path.
#
# The install directories are world-readable and outside /root on purpose.
# Containers run as the unprivileged agentuser, so a tool under
# /root/.local/bin is not on the agent's PATH.
#
# Every input here is pinned to the artifact it resolved to, and
# src/build/pins.json records what that was. scripts/check_pins.sh holds the
# two equal.
FROM node:22.22.3-slim@sha256:e21fc383b50d5347dc7a9f1cae45b8f4e2f0d39f7ade28e4eef7d2934522b752

# Debian's archive publishes a SHA256 per .deb and apt has no syntax to require
# it, so the version is the pin apt enforces and pins.json carries the hash.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates=20250419~deb12u2 \
        curl=7.88.1-10+deb12u15 \
        git=1:2.39.5-0+deb12u3 \
        rsync=3.2.7-1+deb12u6 \
        fd-find=8.6.0-3 \
        ripgrep=13.0.0-4+b2 \
        shellcheck=0.9.0-1 \
        jq=1.6-2.1+deb12u3 \
    && rm -rf /var/lib/apt/lists/*

# uv, from the release archive, with the publisher's checksum verified in the
# same RUN.
ARG UV_VERSION=0.13.7
ARG UV_SHA256=c5221ff41b7892bfc223543883600125f6a47fe845093e0f5bdff4f359196d83
RUN curl -fsSLo /tmp/uv.tar.gz "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
    && echo "${UV_SHA256}  /tmp/uv.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/uv.tar.gz -C /usr/local/bin --strip-components=1 \
    && rm -f /tmp/uv.tar.gz

# Python 3.11 at a pinned patch. uv resolves the standalone build and verifies
# the download against its own recorded table.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN uv python install 3.11.18

ENV PATH="/opt/uv-python/bin:$PATH"

# hadolint -- Dockerfile linter, with the publisher's checksum verified here.
ARG HADOLINT_VERSION=v2.14.0
ARG HADOLINT_SHA256=6bf226944684f56c84dd014e8b979d27425c0148f61b3bd99bcc6f39e9dc5a47
RUN curl -fsSLo /usr/local/bin/hadolint "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64" \
    && echo "${HADOLINT_SHA256}  /usr/local/bin/hadolint" | sha256sum -c - \
    && chmod +x /usr/local/bin/hadolint

# markdownlint-cli2 -- Markdown linter; gate via scripts/check_markdown.sh.
# Installed frozen from its committed lockfile, never re-resolved at build.
COPY src/reasoning/registry/markdownlint-cli2/ /opt/npm/markdownlint-cli2/
RUN cd /opt/npm/markdownlint-cli2 \
    && npm ci \
    && ln -s /opt/npm/markdownlint-cli2/node_modules/.bin/* /usr/local/bin/ \
    && rm -rf /opt/npm/markdownlint-cli2/node_modules/.cache
