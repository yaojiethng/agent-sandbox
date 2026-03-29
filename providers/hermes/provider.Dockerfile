# providers/hermes/provider.Dockerfile
# Reasoning layer image for the Hermes provider.
# Inherits stable install layers from hermes-base (see base.Dockerfile).
# Tagged as hermes-agent-<project>. Built by scripts/build_container.sh --type=agent --provider=hermes.
#
# Rebuilt when provider interface, config, or project-specific content changes.
# Slow install layers (apt, uv, Hermes source, Playwright) live in base.Dockerfile.
ARG BASE_IMAGE=hermes-base
FROM ${BASE_IMAGE}

# -------------------------
# Shared libs (root, before USER switch)
# -------------------------
COPY dirs.sh /libs/dirs.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# Hermes config (agentuser)
# -------------------------
# HERMES_HOME is where Hermes writes config, sessions, and memories.
# Pointed at a user-owned directory inside the container.
# config.yaml and .env are bind-mounted from the host at runtime via
# providers/hermes/docker-compose.hermes.yml — the image-layer directory
# is the fallback only; the bind mounts take precedence.
ENV HERMES_HOME=/home/agentuser/.hermes
RUN mkdir -p "$HERMES_HOME" && \
    cp /opt/hermes/cli-config.yaml.example "$HERMES_HOME/config.yaml" && \
    echo "terminal:" >> "$HERMES_HOME/config.yaml" && \
    echo "  backend: local" >> "$HERMES_HOME/config.yaml"

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

ENTRYPOINT ["hermes"]
