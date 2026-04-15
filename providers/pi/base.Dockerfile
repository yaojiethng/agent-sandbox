# providers/pi/base.Dockerfile
# Stable install layers for the Pi coding agent provider.
# Tagged: pi-base
# Rebuilt only when Node version or Pi version changes.

FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl rsync \
    && rm -rf /var/lib/apt/lists/*

# Install Pi coding agent globally (pinned version)
RUN npm install -g @mariozechner/pi-coding-agent@0.63.1

# Base image ends as root.
# User creation and runtime config belong in provider.Dockerfile.
