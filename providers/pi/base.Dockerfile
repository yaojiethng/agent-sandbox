# providers/pi/base.Dockerfile
# Stable install layers for the Pi coding agent provider.
# Tagged: pi-base
# Rebuilt only when Node version or Pi version changes.

# Node 22.19.0+ required by @earendil-works/pi-coding-agent >= 0.75.x
# Pinned to a specific version for reproducible builds.
FROM node:22.22.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl rsync \
        fd-find ripgrep \
    && rm -rf /var/lib/apt/lists/*

# Install Pi coding agent globally (pinned version, new package owner).
# --ignore-scripts avoids postinstall issues in container builds.
# NOTE: On next Pi bump, also check Node version requirement.
RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.4

# Base image ends as root.
# User creation and runtime config belong in provider.Dockerfile.
