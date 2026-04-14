# providers/claude-code/provider.Dockerfile
# Provider layer for Claude Code. Inherits from claude-code-base.
# Tagged: claude-code-agent-<project>

ARG BASE_IMAGE=claude-code-base
FROM ${BASE_IMAGE}

# Injected by build_context_agent — do not modify these paths.
COPY dirs.sh /libs/dirs.sh
COPY provider-entrypoint.sh /usr/local/bin/provider-entrypoint.sh

RUN useradd -m -u 1001 -s /bin/bash agentuser
RUN mkdir -p /opt/provider-config
USER agentuser

# AGENT_HOME — Claude Code's config and state directory inside the container.
# PROVIDER_NAME — used by provider-entrypoint.sh to derive copy-out target.
ENV PROVIDER_NAME=claude-code
ENV AGENT_HOME=/home/agentuser/.claude
ENV PROVIDER_CONFIG_DIR=/opt/provider-config

RUN mkdir -p /home/agentuser/workspace/input \
             /home/agentuser/workspace/output

WORKDIR /home/agentuser/sandbox

HEALTHCHECK --interval=2s --timeout=5s --start-period=60s --retries=10 \
  CMD test -d /home/agentuser/sandbox/.git

# provider-entrypoint.sh seeds config into AGENT_HOME, registers a copy-out
# EXIT trap, then execs the agent command.
ENTRYPOINT ["provider-entrypoint.sh", "claude"]
