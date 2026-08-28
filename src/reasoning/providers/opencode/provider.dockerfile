# providers/opencode/provider.dockerfile
# Reasoning layer image for the OpenCode provider.
# Inherits stable install layers from opencode-base (see base.dockerfile).
# Tagged as opencode-agent-<project>. Built by scripts/build_container.sh --type=agent --provider=opencode.
#
# Rebuilt when provider interface, shared libs, or project-specific content changes.
# Slow install layers (apt, npm, opencode-ai) live in base.dockerfile.
#
# Provider contract (harness interface):
#   AGENT_HOME     --  where OpenCode writes config and state
#   PROVIDER_NAME  --  used by provider-entrypoint.sh for copy-out target naming
#   ENTRYPOINT     --  provider-entrypoint.sh wraps the agent command; seeds config
#                   and registers copy-out trap before exec-ing opencode
ARG BASE_IMAGE=opencode-base
FROM ${BASE_IMAGE}

ARG HOST_UID=1000
ARG HOST_GID=1000

# -------------------------
# Shared libs
# -------------------------
# Build context is the repo root; COPY paths are repo-relative.
COPY src/libs/                                  /opt/sandbox/lib/
COPY src/reasoning/entrypoint.sh                /opt/sandbox/bin/provider-entrypoint.sh
RUN chmod +x /opt/sandbox/bin/provider-entrypoint.sh
COPY src/reasoning/agent/skills/                 /opt/workflow/agent/skills/
COPY src/reasoning/agent/prompts/                /opt/workflow/agent/prompts/
COPY docs/architecture/                          /opt/sandbox/docs/architecture/
COPY docs/concepts/                              /opt/sandbox/docs/concepts/

# -------------------------
# Non-root user
# -------------------------
# Create agentuser at the host's UID to avoid bind mount permission conflicts.
RUN if ! id -u ${HOST_UID} >/dev/null 2>&1; then \
      useradd -l -m -u ${HOST_UID} -s /bin/bash agentuser; \
    elif [ "$(id -nu ${HOST_UID})" != "agentuser" ]; then \
      existing_user="$(id -nu ${HOST_UID})"; \
      existing_group="$(id -ng ${HOST_UID})"; \
      usermod -l agentuser "$existing_user"; \
      groupmod -n agentuser "$existing_group" 2>/dev/null || true; \
      usermod -d /home/agentuser -m agentuser; \
    fi

# Create key directories before user switch so agentuser
# owns them. Docker bind mounts on macOS create parent dirs as root
# when they don't exist in the image, which blocks writes by the
# unprivileged user.
RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output && \
    chown -R agentuser:agentuser /home/agentuser/workspace

USER agentuser

# -------------------------
# Provider identity
# -------------------------
ENV PROVIDER_NAME=opencode
ENV AGENT_HOME=/home/agentuser/.opencode

# -------------------------
# Working directories
# -------------------------
# sandbox/ is NOT pre-created here  --  it is provided exclusively by the
# capability layer container via --volumes-from. Pre-creating it would
# shadow the capability layer's directory.

WORKDIR /home/agentuser/sandbox

# -------------------------
# Health check
# -------------------------
HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config and registers copy-out trap,
# then execs opencode. Subcommand and args passed via compose:
#   standard: no override  --  runs as `opencode` with no args
#   serve:    docker-compose.serve.yml sets command: ["serve", ...]
#   dry-run:  docker compose exec agent bash /dry_run.sh (bypasses entrypoint)
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "opencode"]
