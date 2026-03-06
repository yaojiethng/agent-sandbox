# Dockerfile
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/usr/local/bin:$PATH

# Install required packages
RUN apt-get update && apt-get install -y \
    bash curl git ca-certificates 
RUN apt-get install -y python3 python3-pip nodejs npm \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g opencode-ai

# Copy entrypoint script
COPY container-entrypoint.sh /usr/local/bin/container-entrypoint.sh
RUN chmod +x /usr/local/bin/container-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]

# Create a non-root user for the agent
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# Create project/ and sandbox/ as agentuser so file mounts are not blocked by ownership.
# project/ must exist and be owned by agentuser before Docker mounts files into it at runtime.
RUN mkdir -p /home/agentuser/project /home/agentuser/sandbox

# COPY --chown=agentuser:agentuser config/opencode.json /home/agentuser/.config/opencode/config.json
# COPY agent /home/agentuser/agent

WORKDIR /home/agentuser/sandbox
CMD ["opencode"]