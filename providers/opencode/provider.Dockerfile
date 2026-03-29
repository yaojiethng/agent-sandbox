# providers/opencode/provider.Dockerfile
# Reasoning layer image for the OpenCode provider.
# Inherits stable install layers from opencode-base (see base.Dockerfile).
# Tagged as opencode-agent-<project>. Built by scripts/build_container.sh --type=agent --provider=opencode.
#
# Rebuilt when provider interface, shared libs, or project-specific content changes.
# Slow install layers (apt, npm, opencode-ai) live in base.Dockerfile.
ARG BASE_IMAGE=opencode-base
FROM ${BASE_IMAGE}

# -------------------------
# Shared libs
# -------------------------
# dirs.sh is sourced by dry_run.sh inside the container.
# No entrypoint script — opencode is exec'd directly via ENTRYPOINT.
# Serve args and dry-run invocation are handled by compose overlays.
# Build context is a temp directory populated by build_context in libs/build.sh;
# files are copied flat so paths here match the temp dir layout.
COPY dirs.sh /libs/dirs.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

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
