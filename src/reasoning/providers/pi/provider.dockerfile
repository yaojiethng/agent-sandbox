# providers/pi/provider.dockerfile
# Provider layer for Pi. Inherits from pi-base.
# Tagged: pi-agent-<project>

ARG BASE_IMAGE=pi-base
FROM ${BASE_IMAGE}

ARG HOST_UID=1000
ARG HOST_GID=1000

# Injected by build_context_agent — do not modify these paths.
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY provider-preflight.sh /opt/sandbox/bin/provider-preflight.sh
COPY diff.sh /opt/sandbox/lib/diff.sh
COPY diff_export.sh /opt/sandbox/lib/diff_export.sh
COPY session_state.sh /opt/sandbox/lib/session_state.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh

# Workflow files — prompts and skills the agent uses at runtime.
COPY agent/skills/ /opt/workflow/agent/skills/
COPY agent/prompts/ /opt/workflow/agent/prompts/

# Provider config template — copied to AGENT_HOME at startup by
# _provision_agent_home (see provider-entrypoint.sh). Bind-mounted subdirs
# (prompts/, sessions/, skills/) shadow the template at runtime.
COPY agent/config/ /opt/workflow/agent/config/

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

# AGENT_HOME — most files are container-local. Only prompts/, sessions/,
# skills/ are bind-mounted from host per the selective mount layout.
ENV AGENT_HOME=/home/agentuser/.pi
ENV WORKSPACE_DIR=/home/agentuser/workspace
ENV PROVIDER_NAME=pi

# Create key directories before user switch so agentuser
# owns it. Docker bind mounts create parent dirs as root when they
# don't exist in the image, which would block the entrypoint's
# copy-in provisioning step.
RUN mkdir -p $AGENT_HOME/agent/prompts \
             $AGENT_HOME/agent/sessions \
             $AGENT_HOME/agent/skills \
             $AGENT_HOME/agent/bin \
             $WORKSPACE_DIR/input \
             $WORKSPACE_DIR/output

RUN chown -R ${HOST_UID}:${HOST_GID} $AGENT_HOME
RUN chown -R ${HOST_UID}:${HOST_GID} /opt/workflow/agent
RUN chown -R ${HOST_UID}:${HOST_GID} $WORKSPACE_DIR

USER agentuser

ENV PROVIDER_NAME=pi
ENV AGENT_HOME=/home/agentuser/.pi


WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config into AGENT_HOME, registers a copy-out
# EXIT trap, then execs the agent command.
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "pi"]
