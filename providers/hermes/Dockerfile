# providers/hermes/Dockerfile (reasoning layer)
# Runs the Hermes agent. Snapshot unpacking and diff pipeline are
# handled by the capability layer container (Dockerfile.sandbox).
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

# -------------------------
# Shared libs (root, before USER switch)
# -------------------------
COPY dirs.sh /libs/dirs.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# Hermes config (agentuser)
# -------------------------
# HERMES_HOME is where Hermes writes config, sessions, and memories.
# We point it at a user-owned directory inside the container — there is
# no host-mounted data volume in this setup. The harness manages isolation
# via the capability layer sandbox; Hermes state is ephemeral per session.
ENV HERMES_HOME=/home/agentuser/.hermes
RUN mkdir -p "$HERMES_HOME"

# Bootstrap config so Hermes starts without interactive setup.
# terminal.backend: local disables Hermes's own Docker sandbox — the
# harness handles isolation; Hermes must not try to spawn containers.
RUN mkdir -p "$HERMES_HOME" && \
    cp /opt/hermes/cli-config.yaml.example "$HERMES_HOME/config.yaml" && \
    echo "terminal:" >> "$HERMES_HOME/config.yaml" && \
    echo "  backend: local" >> "$HERMES_HOME/config.yaml"

# -------------------------
# Working directories
# -------------------------
# sandbox/ is NOT pre-created here — provided by the capability layer
# via --volumes-from. workspace/ dirs are bind-mounted from SANDBOX_DIR.
RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

# -------------------------
# Health check
# -------------------------
HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# No CMD — subcommand is injected by run.sh per mode:
#   standard: docker compose run --rm agent chat
#   serve:    command: ["api"] in docker-compose.serve.yml
#   dry-run:  docker compose exec agent bash /dry_run.sh (bypasses entrypoint)
ENTRYPOINT ["hermes"]
