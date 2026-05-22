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

RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# AGENT_HOME — Pi's config and state directory inside the container.
# Bind-mounted directly from host; no copy-in/copy-out needed.
ENV PROVIDER_NAME=pi
ENV AGENT_HOME=/home/agentuser/.pi

RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config into AGENT_HOME, registers a copy-out
# EXIT trap, then execs the agent command.
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "pi"]
