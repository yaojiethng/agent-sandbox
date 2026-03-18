# Dockerfile (reasoning layer)
# Runs the agent (OpenCode). Snapshot unpacking and diff pipeline are
# handled by the capability layer container (Dockerfile.sandbox).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

# -------------------------
# System packages (root)
# -------------------------
RUN apt-get update && apt-get install -y \
    bash curl git ca-certificates \
    python3 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Shared libs (root, before USER switch)
# -------------------------
# dirs.sh is sourced by dry_run.sh inside the container.
# No entrypoint script — opencode is exec'd directly via ENTRYPOINT.
# Serve args and dry-run invocation are handled by compose overlays.
COPY libs/dirs.sh /libs/dirs.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# npm global install as agentuser
# -------------------------
# By default, npm installs globals to /usr/lib/node_modules (root-owned).
# Redirecting NPM_CONFIG_PREFIX to a user-owned directory allows non-root
# global installs. Any future `npm install -g` as a non-root user needs
# these two ENV lines set beforehand.
ENV NPM_CONFIG_PREFIX=/home/agentuser/.npm-global
ENV PATH=/home/agentuser/.npm-global/bin:$PATH

RUN npm install -g opencode-ai

# -------------------------
# Working directories
# -------------------------
# sandbox/ is NOT pre-created here — it is provided exclusively by the
# capability layer container via --volumes-from. Pre-creating it would
# shadow the capability layer's directory. If the capability layer is not
# running, --volumes-from fails and this container cannot start.
#
# workspace/input/ and workspace/output/ are bind-mounted from SANDBOX_DIR
# on the host; created here as agentuser so mounts are not blocked by
# ownership.
RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

# -------------------------
# Health check
# -------------------------
# Checks that sandbox/.git exists — confirming the capability layer has
# completed snapshot init before the agent starts. This is a defence-in-depth
# check; the primary gate is the compose depends_on: service_healthy condition
# on the capability layer container.
HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# opencode is exec'd directly. Subcommand and args are passed via compose:
#   standard: no override — runs as `opencode` with no args
#   serve:    docker-compose.serve.yml sets command: ["serve", ...]
#   dry-run:  docker compose exec agent bash /dry_run.sh  (bypasses entrypoint)
ENTRYPOINT ["opencode"]
