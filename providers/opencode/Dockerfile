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
# Entrypoint (root, before USER switch)
# -------------------------
# snapshot.sh and diff.sh are not copied here — they belong to the
# capability layer image only. container-entrypoint.sh lives in scripts/
# as it is provider-agnostic.
COPY scripts/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh
COPY libs/dirs.sh /libs/dirs.sh
RUN chmod +x /usr/local/bin/container-entrypoint.sh

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
# .agent-input/ and .workspace/ are bind-mounted from SANDBOX_DIR on the
# host; created here as agentuser so mounts are not blocked by ownership.
RUN mkdir -p /home/agentuser/.agent-input \
             /home/agentuser/.workspace

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

ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
CMD ["opencode"]
