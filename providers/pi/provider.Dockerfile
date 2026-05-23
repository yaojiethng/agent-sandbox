# providers/pi/provider.Dockerfile
# Provider layer for Pi. Inherits from pi-base.
# Tagged: pi-agent-<project>

ARG BASE_IMAGE=pi-base
FROM ${BASE_IMAGE}

# Injected by build_context_agent — do not modify these paths.
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY provider-entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY provider-preflight.sh /opt/sandbox/bin/provider-preflight.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY session.sh /opt/sandbox/lib/session.sh
COPY routing.sh /opt/sandbox/lib/routing.sh

# Workflow files — prompts and skills the agent uses at runtime.
COPY agent/skills/ /opt/workflow/agent/skills/
COPY agent/prompts/ /opt/workflow/agent/prompts/

# Provider config template — copied to AGENT_HOME at startup by
# _provision_agent_home (see provider-entrypoint.sh). Bind-mounted subdirs
# (prompts/, sessions/, skills/) shadow the template at runtime.
COPY agent/config/ /opt/workflow/agent/config/

RUN useradd -m -u 1001 -s /bin/bash agentuser

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

USER agentuser

ENV PROVIDER_NAME=pi
ENV AGENT_HOME=/home/agentuser/.pi

RUN chown -R agentuser:agentuser $AGENT_HOME
RUN chown -R agentuser:agentuser /opt/workflow/agent
RUN chown -R agentuser:agentuser $WORKSPACE_DIR

WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config into AGENT_HOME, registers a copy-out
# EXIT trap, then execs the agent command.
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "pi"]
