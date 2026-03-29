# providers/hermes/provider.Dockerfile
# Reasoning layer image for the Hermes provider.
# Inherits stable install layers from hermes-base (see base.Dockerfile).
# Tagged as hermes-agent-<project>. Built by scripts/build_container.sh --type=agent --provider=hermes.
#
# Rebuilt when provider interface, config, or project-specific content changes.
# Slow install layers (apt, uv, Hermes source, Playwright) live in base.Dockerfile.
#
# Provider contract (harness interface):
#   AGENT_HOME    — where Hermes writes config, sessions, and memories
#   PROVIDER_NAME — used by provider-entrypoint.sh for copy-out target naming
#   ENTRYPOINT    — provider-entrypoint.sh wraps the agent command; seeds config
#                   and registers copy-out trap before exec-ing hermes
#   config/       — default config files baked into /opt/context/config/ via
#                   build context; seeded into AGENT_HOME if absent at startup
ARG BASE_IMAGE=hermes-base
FROM ${BASE_IMAGE}

# -------------------------
# Shared libs (root, before USER switch)
# -------------------------
# Injected by build_context_agent — cache miss if either file changes.
COPY dirs.sh /libs/dirs.sh
COPY provider-entrypoint.sh /usr/local/bin/provider-entrypoint.sh

# -------------------------
# Provider config seed (root, before USER switch)
# -------------------------
# Default config files from providers/hermes/config/, injected by
# build_context_agent. Seeded into AGENT_HOME by provider-entrypoint.sh
# at container start if files are absent.
COPY config/ /opt/context/config/

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# Provider identity
# -------------------------
ENV PROVIDER_NAME=hermes
ENV AGENT_HOME=/home/agentuser/.hermes

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

ENTRYPOINT ["provider-entrypoint.sh", "hermes"]
