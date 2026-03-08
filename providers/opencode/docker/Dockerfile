# Dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

# -------------------------
# System packages (root)
# -------------------------
RUN apt-get update && apt-get install -y \
    bash curl git ca-certificates \
    python3 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Entrypoint (root, before USER switch)
# -------------------------
COPY container-entrypoint.sh /usr/local/bin/container-entrypoint.sh
RUN chmod +x /usr/local/bin/container-entrypoint.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# npm global install as agentuser
# -------------------------
# By default, npm installs globals to /usr/lib/node_modules (root-owned).
# Redirecting NPM_CONFIG_PREFIX to a user-owned directory allows non-root
# global installs. Any future `npm install -g` as a non-root user needs
# these two ENV lines set beforehand.
ENV NPM_CONFIG_PREFIX=/home/agentuser/.npm-global
ENV PATH=/home/agentuser/.npm-global/bin:$PATH

RUN npm install -g opencode-ai

# -------------------------
# Working directories
# -------------------------
# project/ and sandbox/ created as agentuser so Docker file mounts are not
# blocked by ownership at runtime.
RUN mkdir -p /home/agentuser/project /home/agentuser/sandbox

WORKDIR /home/agentuser/sandbox
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
CMD ["opencode"]
