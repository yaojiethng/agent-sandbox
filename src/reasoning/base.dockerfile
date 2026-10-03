# reasoning/base.dockerfile
# Shared runtime base for every reasoning layer provider (hermes, opencode, pi).
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
# the harness requires. uv installs the current 3.11.x into /opt/uv-python,
# and UV_PYTHON_INSTALL_DIR points at it so a provider base can `uv venv`
# without repeating the path.
#
# The install directories are world-readable and outside /root on purpose.
# Containers run as the unprivileged agentuser, so a tool under
# /root/.local/bin is not on the agent's PATH.
FROM node:22.22.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git \
        rsync fd-find ripgrep shellcheck jq \
    && rm -rf /var/lib/apt/lists/*

# uv, on the system PATH for every user
ENV UV_INSTALL_DIR=/usr/local/bin
RUN curl -LsSf https://astral.sh/uv/install.sh | sh

# Python 3.11 (current patch level, at or above 3.11.12)
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN uv python install 3.11

ENV PATH="/opt/uv-python/bin:$PATH"

# hadolint -- Dockerfile linter
RUN curl -Lo /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-Linux-x86_64 \
    && chmod +x /usr/local/bin/hadolint

# markdownlint-cli2 -- Markdown linter; gate via scripts/check_markdown.sh
RUN npm install -g markdownlint-cli2@0.23.2
