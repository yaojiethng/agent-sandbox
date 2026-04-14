# providers/claude-code/base.Dockerfile
# Stable install layers for the Claude Code provider.
# Tagged: claude-code-base
# Rebuilt only when Node version or Claude Code version changes.

FROM node:20-slim

# Install Claude Code globally (pinned version).
RUN npm install -g @anthropic-ai/claude-code@2.1.100

# Base image ends as root.
# User creation and runtime config belong in provider.Dockerfile.
