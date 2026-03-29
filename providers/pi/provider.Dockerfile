# providers/pi/provider.Dockerfile
# Provider layer for Pi. Inherits from pi-base.
# Tagged: pi-agent-<project>

ARG BASE_IMAGE=pi-base
FROM ${BASE_IMAGE}

# Injected by build_context_agent — do not modify these paths.
COPY dirs.sh /libs/dirs.sh
COPY provider-entrypoint.sh /usr/local/bin/provider-entrypoint.sh

# Provider config seed — injected by build_context_agent from providers/pi/config/.
COPY config/ /opt/context/config/

RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# AGENT_HOME — Pi's config and state directory inside the container.
# PROVIDER_NAME — used by provider-entrypoint.sh to derive copy-out target.
ENV PROVIDER_NAME=pi
ENV AGENT_HOME=/home/agentuser/.pi/agent

RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config into AGENT_HOME, registers a copy-out
# EXIT trap, then execs the agent command.
ENTRYPOINT ["provider-entrypoint.sh", "pi"]
