# providers/pi/provider.dockerfile
# Provider layer for Pi. Inherits from pi-base.
# Tagged: pi-agent-<project>

ARG BASE_IMAGE=pi-base
FROM ${BASE_IMAGE}

ARG HOST_UID=1000
ARG HOST_GID=1000

# Build context is the repo root; COPY paths are repo-relative.
COPY src/libs/                                          /opt/sandbox/lib/
COPY src/reasoning/entrypoint.sh                        /opt/sandbox/bin/provider-entrypoint.sh
COPY src/reasoning/providers/pi/preflight.sh            /opt/sandbox/bin/provider-preflight.sh
COPY src/reasoning/agent/skills/                        /opt/workflow/agent/skills/
COPY src/reasoning/agent/prompts/                       /opt/workflow/agent/prompts/
COPY src/reasoning/providers/pi/config/                 /opt/workflow/agent/config/
COPY docs/architecture/                                 /opt/sandbox/docs/architecture/
COPY docs/concepts/                                     /opt/sandbox/docs/concepts/
RUN chmod +x /opt/sandbox/bin/provider-entrypoint.sh

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

# AGENT_HOME  --  most files are container-local. Only prompts/, sessions/,
# skills/ are bind-mounted from host per the selective mount layout.
ENV AGENT_HOME=/home/agentuser/.pi
ENV WORKSPACE_DIR=/home/agentuser/workspace
ENV PROVIDER_NAME=pi

# Create key directories before user switch so agentuser
# owns them. Docker bind mounts on macOS create parent dirs as root when they
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
RUN pi install npm:pi-opencode-provider
RUN pi install npm:pi-copy-on-select

CMD ["pi"]
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh"]
