# providers/opencode/provider.Dockerfile
# Reasoning layer image for the OpenCode provider.
# Inherits stable install layers from opencode-base (see base.Dockerfile).
# Tagged as opencode-agent-<project>. Built by scripts/build_container.sh --type=agent --provider=opencode.
#
# Rebuilt when provider interface, shared libs, or project-specific content changes.
# Slow install layers (apt, npm, opencode-ai) live in base.Dockerfile.
#
# Provider contract (harness interface):
#   AGENT_HOME    — where OpenCode writes config and state
#   PROVIDER_NAME — used by provider-entrypoint.sh for copy-out target naming
#   ENTRYPOINT    — provider-entrypoint.sh wraps the agent command; seeds config
#                   and registers copy-out trap before exec-ing opencode
ARG BASE_IMAGE=opencode-base
FROM ${BASE_IMAGE}

# -------------------------
# Shared libs
# -------------------------
# Injected by build_context_agent — cache miss if either file changes.
# dirs.sh is sourced by dry_run.sh inside the container.
COPY dirs.sh /libs/dirs.sh
COPY provider-entrypoint.sh /usr/local/bin/provider-entrypoint.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# Provider identity
# -------------------------
ENV PROVIDER_NAME=opencode
ENV AGENT_HOME=/home/agentuser/.opencode

# -------------------------
# Working directories
# -------------------------
# sandbox/ is NOT pre-created here — it is provided exclusively by the
# capability layer container via --volumes-from. Pre-creating it would
# shadow the capability layer's directory.
RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

# -------------------------
# Health check
# -------------------------
HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config and registers copy-out trap,
# then execs opencode. Subcommand and args passed via compose:
#   standard: no override — runs as `opencode` with no args
#   serve:    docker-compose.serve.yml sets command: ["serve", ...]
#   dry-run:  docker compose exec agent bash /dry_run.sh (bypasses entrypoint)
ENTRYPOINT ["provider-entrypoint.sh", "opencode"]
