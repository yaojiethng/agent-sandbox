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
ARG BASE_IMAGE=hermes-base
FROM ${BASE_IMAGE}

ARG HOST_UID=1000
ARG HOST_GID=1000

# -------------------------
# Shared libs (root, before USER switch)
# -------------------------
# Injected by build_context_agent — cache miss if either file changes.
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY session_state.sh /opt/sandbox/lib/session_state.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY diff_export.sh /opt/sandbox/lib/diff_export.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh
COPY diff_export.sh /opt/sandbox/lib/diff_export.sh

# Workflow files — prompts and skills the agent uses at runtime.
COPY agent/skills/ /opt/workflow/agent/skills/
COPY agent/prompts/ /opt/workflow/agent/prompts/

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

ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "hermes"]
