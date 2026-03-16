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
    && rm -rf /var/libs/apt/lists/*

# -------------------------
# Entrypoint and libs (root, before USER switch)
# -------------------------
COPY providers/opencode/container-entrypoint.sh /usr/local/bin/container-entrypoint.sh
COPY libs/snapshot.sh /libs/snapshot.sh
COPY libs/diff.sh /libs/diff.sh
RUN chmod +x /usr/local/bin/container-entrypoint.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# npm global install as agentuser
# -------------------------
# By default, npm installs globals to /usr/libs/node_modules (root-owned).
# Redirecting NPM_CONFIG_PREFIX to a user-owned directory allows non-root
# global installs. Any future `npm install -g` as a non-root user needs
# these two ENV lines set beforehand.
ENV NPM_CONFIG_PREFIX=/home/agentuser/.npm-global
ENV PATH=/home/agentuser/.npm-global/bin:$PATH

RUN npm install -g opencode-ai

# -------------------------
# Working directories
# -------------------------
# sandbox/ is container-local — agent works here.
# .bootstrap/ and .workspace/ are mount points — created as agentuser
# so Docker bind mounts are not blocked by ownership at runtime.
RUN mkdir -p /home/agentuser/sandbox \
             /home/agentuser/.bootstrap \
             /home/agentuser/.workspace

WORKDIR /home/agentuser/sandbox
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]
CMD ["opencode"]
