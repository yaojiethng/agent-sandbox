# providers/claude-code/provider.Dockerfile
# Provider layer for Claude Code. Inherits from claude-code-base.
# Tagged: claude-code-agent-<project>

ARG BASE_IMAGE=claude-code-base
FROM ${BASE_IMAGE}

# Injected by build_context_agent — do not modify these paths.
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY provider-entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
COPY session.sh /opt/sandbox/lib/session.sh
COPY routing.sh /opt/sandbox/lib/routing.sh

# Workflow files — prompts and skills the agent uses at runtime.
COPY agent/skills/ /opt/workflow/agent/skills/
COPY agent/prompts/ /opt/workflow/agent/prompts/

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
ENV PATH=/opt/sandbox/bin:$PATH
ENTRYPOINT ["/opt/sandbox/bin/provider-entrypoint.sh", "claude"]
